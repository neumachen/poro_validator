module PoroValidator
  class ErrorStore
    # Kernel#class and #singleton_methods, bound per call so that an object's
    # own definitions cannot change what they report.
    KERNEL_CLASS = ::Kernel.instance_method(:class)
    KERNEL_SINGLETON_METHODS = ::Kernel.instance_method(:singleton_methods)
    # BasicObject#equal?, bound per call for the same reason.
    SAME_OBJECT = ::BasicObject.instance_method(:equal?)
    private_constant :KERNEL_CLASS, :KERNEL_SINGLETON_METHODS, :SAME_OBJECT

    attr_reader :data

    def initialize(data = {})
      @data = {}
      # The path each key's text was last written from by #set, for keys
      # written from an ordinary path (see #ordinary_names): a frozen copy of
      # the text => the path's names, frozen. It holds no messages and nothing
      # a caller passed in, and every library write to a text replaces or
      # removes that text's entry.
      @paths = {}
      self.load(data)
    end

    def get(key)
      validate_key!(key)
      @data[lookup_key(key)]
    end

    # Also records the names of an ordinary path under the key's text, or
    # forgets any recorded for that text. The names are taken before the key
    # is rendered, and kept only if they render to the same text.
    def set(key, value = nil, &block)
      validate_key!(key)
      data = @data
      paths = path_records
      names = ordinary_names(key) if paths
      text = written_key(key)
      names = nil if names && written_key(names) != text
      value = yield if block_given?
      data[text] = value
      if names
        paths[record_key(text).freeze] = names unless paths.frozen?
      elsif paths
        forget(paths, text)
      end
      value
    end

    def set?(key)
      validate_key!(key)
      @data.keys.include?(lookup_key(key))
    end

    # Also forgets any path recorded for each text it writes.
    def load(data)
      data.each do |key, value|
        validate_key!(key)
        target = @data
        paths = path_records
        text = stored_key(key)
        target[text] = value
        forget(paths, text) if paths
      end
    end

    def reset
      data = @data = {}
      @paths = {} if path_records
      data
    end

    # @private
    # The names of the ordinary path the entry under text was last written
    # from by #set, frozen, or nil. Reads only.
    def __path__(text)
      paths = path_records
      key = paths && record_key(text)
      names = paths[key] if key
      frozen_names(names) if names
    end

    # @private
    # For Errors#add, after #set? found key and #get returned messages:
    # appends the message the block builds to messages and returns what #<<
    # returns. Each recorded entry whose value is messages itself keeps its
    # path only if key names that path; this is decided before the block runs
    # and applied after the append succeeds. An object from anywhere else
    # changes no entry, so no record changes. Key is not looked up again.
    def __append__(key, messages)
      paths = path_records
      unless paths.nil? || paths.empty?
        data = @data
        names = ordinary_names(key)
        stale = paths.select do |text, recorded|
          data.key?(text) && SAME_OBJECT.bind_call(data[text], messages) && names != recorded
        end.keys
      end
      appended = messages << yield
      stale.each { |text| paths.delete(text) } if stale && !paths.frozen?
      appended
    end

    private

    # Keys are stored as text. Nested attribute keys are hashes, so render
    # them the same way on every Ruby (Hash#inspect changed in Ruby 3.4).
    def stored_key(key)
      if key.is_a?(::Hash) || key.is_a?(::Array)
        Utils::StableInspect.call(key)
      else
        key.to_s
      end
    end

    # The key #set writes. An Array path is stored as the nested Hash it
    # describes: [:address, :line1] as "{:address=>:line1}".
    def written_key(key)
      return stored_key(key) unless key.is_a?(::Array)

      stored_key(key.flatten.reverse.inject { |a, n| { n => a } })
    end

    # The key #get and #set? read. For an Array path it is the key #set writes
    # if the store has that key, even with a nil or false value. Otherwise it
    # is the Array's own rendering, which #load writes and older data may use.
    # A recursive Array only has the latter, since #set can't flatten it.
    def lookup_key(key)
      if key.is_a?(::Array) && !recursive_array?(key)
        path_key = written_key(key)
        return path_key if @data.key?(path_key)
      end
      stored_key(key)
    end

    def recursive_array?(array, enclosing = {}.compare_by_identity)
      return true if enclosing.key?(array)

      enclosing[array] = true
      recursive = array.any? do |item|
        item.is_a?(::Array) && recursive_array?(item, enclosing)
      end
      enclosing.delete(array)
      recursive
    end

    # The path records, or nil for a store restored from a dump made before
    # they existed. Such a store keeps working as before and never gets any.
    def path_records
      paths = @paths
      paths if ::Hash === paths
    end

    # A record's key: a plain copy of a stored key's text, so that comparing
    # it calls nothing the text object defines. Nil when the text is no String.
    def record_key(text)
      ::String.new(text) if ::String === text
    end

    # Recorded names, frozen: the record itself when it is frozen throughout,
    # as #set makes it and as a deep-frozen Marshal.load leaves it; otherwise
    # a frozen copy. A normal Marshal.load leaves the record's Array and
    # Strings unfrozen, and a reader must neither hand those out nor freeze
    # them in place.
    def frozen_names(names)
      return names if names.frozen? && names.all?(&:frozen?)

      names.map { |name| name.frozen? ? name : ::String.new(name).freeze }.freeze
    end

    # Forgets the path recorded for text. A text that is no String can only
    # come from a key whose own #inspect or #to_s returns one; it cannot be
    # compared without calling it, so every record is forgotten.
    def forget(paths, text)
      return if paths.frozen?

      key = record_key(text)
      key ? paths.delete(key) : paths.clear
    end

    # The names of key when it is an ordinary path: a plain Array (exactly
    # Array, no singleton methods) whose elements, at any depth, are Arrays,
    # Symbols or plain Strings, with no Array met twice and at least two
    # names. Returns them as a frozen Array of Symbols and frozen String
    # copies, or nil. Uses only Module#===, the bound Kernel methods and
    # Array.new/String.new copies, so nothing a caller's object defines runs.
    def ordinary_names(key)
      return unless ::Array === key && plain?(key, ::Array)

      names = []
      seen = {}.compare_by_identity
      pending = [key]
      until pending.empty?
        item = pending.pop
        if ::Array === item
          return if seen.key?(item)
          seen[item] = true
          pending.concat(::Array.new(item).reverse!)
        elsif ::Symbol === item
          names << item
        elsif ::String === item && plain?(item, ::String)
          names << ::String.new(item).freeze
        else
          return
        end
      end
      names.freeze if names.size > 1
    end

    def plain?(object, klass)
      klass.equal?(KERNEL_CLASS.bind_call(object)) &&
        KERNEL_SINGLETON_METHODS.bind_call(object).empty?
    end

    def validate_key!(key)
      unless key.is_a?(::String) || key.is_a?(::Symbol) || key.is_a?(::Array) \
        || key.is_a?(::Hash)
        raise ::PoroValidator::InvalidType.new(
          "only String, Symbol, Array or Hash are allowed! invalid key: #{key.inspect}"
        )
      end
    end
  end
end
