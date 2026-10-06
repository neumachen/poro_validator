module PoroValidator
  module Utils
    # Renders a value the way Hash#inspect did before Ruby 3.4
    # ({:key=>value}), so error messages and nested error keys read the same
    # on every Ruby version. Values other than hashes and arrays use their own
    # #inspect, and so do hashes and arrays whose #inspect is not Hash's or
    # Array's own (one defined on a subclass, a module or the object itself);
    # that text is used unchanged.
    #
    # A hash or array that contains itself is rendered as {...} or [...] where
    # it recurs, as Ruby's #inspect does. Only the hashes and arrays enclosing
    # the current value count, so a value shared by two branches is rendered
    # in full in both.
    #
    # @param value [Object] value to render
    #
    # @return [String]
    #
    # @example
    #  StableInspect.call({ in: 1..10 }) #=> "{:in=>1..10}"
    #  StableInspect.call({ address: { country: :code } })
    #  #=> "{:address=>{:country=>:code}}"
    #  list = [1]
    #  list << list
    #  StableInspect.call(list) #=> "[1, [...]]"
    module StableInspect
      # Kernel#method itself, so an object that defines its own #method (a
      # common attribute name) cannot hide which #inspect it uses.
      KERNEL_METHOD = ::Kernel.instance_method(:method)
      private_constant :KERNEL_METHOD

      def self.call(value)
        render(value, {}.compare_by_identity)
      end

      # enclosing holds the hashes and arrays being rendered around value,
      # compared by identity. Each call builds its own, so nothing is kept
      # between calls or on the rendered objects.
      def self.render(value, enclosing)
        case value
        when ::Hash
          return value.inspect if custom_inspect?(value, ::Hash)
          return "{...}" if enclosing.key?(value)

          within(value, enclosing) do
            pairs = value.map do |key, val|
              "#{render(key, enclosing)}=>#{render(val, enclosing)}"
            end
            "{#{pairs.join(', ')}}"
          end
        when ::Array
          return value.inspect if custom_inspect?(value, ::Array)
          return "[...]" if enclosing.key?(value)

          within(value, enclosing) do
            "[#{value.map { |item| render(item, enclosing) }.join(', ')}]"
          end
        else
          value.inspect
        end
      end

      def self.within(container, enclosing)
        enclosing[container] = true
        yield
      ensure
        enclosing.delete(container)
      end

      def self.custom_inspect?(value, base)
        KERNEL_METHOD.bind(value).call(:inspect).owner != base
      end

      private_class_method :render, :within, :custom_inspect?
    end
  end
end
