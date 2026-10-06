require 'spec_helper'

# WithValidator transfers child errors using recorded path metadata from
# ErrorStore#__path__ (the adopted foundation). Every scenario exercises the
# public parent `valid?` path and asserts the actual entity the child received
# where wrapper status determines path stripping.
RSpec.describe "Structured composition paths", :aggregate_failures, type: :feature do
  # ---- Helpers ----

  def child_class(freeze: false, after_valid: nil, &declarations)
    Class.new do
      include PoroValidator.validator

      singleton_class.attr_accessor :instances
      self.instances = []
      attr_reader :arrays_after_valid, :contents_after_valid

      define_method(:initialize) { self.class.instances << self }

      define_method(:valid?) do |entity|
        result = super(entity)
        after_valid.call(errors) if after_valid
        data = errors.store.data
        if freeze
          data.each_value(&:freeze)
          data.freeze
        end
        @arrays_after_valid = data.values
        @contents_after_valid = data.map { |key, messages| [key, messages.dup] }
        result
      end

      class_eval(&declarations)
    end
  end

  # A manually-prepared child: wraps a pre-built Errors inside a class
  # whose #valid? records the received entity and returns false. The
  # instance is created during #new so the child's store is live.
  def prepared_child(errors)
    instances = []
    klass = Class.new do
      define_singleton_method(:instances) { instances }
      attr_reader :errors, :received
      define_method(:initialize) { @errors = errors; instances << self }
      define_method(:valid?) { |entity| @received = entity; false }
    end
    klass
  end

  def parent_for(child_class, nested: false)
    Class.new do
      include PoroValidator.validator
      if nested
        validates :address do
          validates :country, with: child_class
        end
      else
        validates :address, with: child_class
      end
    end.new
  end

  # Build an Errors with messages at the given paths.
  def errors_for(hash)
    errs = PoroValidator::Errors.new
    hash.each { |path, msg| errs.add(path, msg || 'message') }
    errs
  end

  def marshal_roundtrip(object, freeze: false)
    Marshal.load(Marshal.dump(object), freeze: freeze)
  end

  def load_legacy(name)
    Marshal.load(File.binread(File.join(File.expand_path('../fixtures/legacy', __dir__), name)))
  end

  def expect_unchanged(child)
    data = child.errors.store.data
    expect(data.map { |key, messages| [key, messages] }).to eq(child.contents_after_valid)
    data.values.zip(child.arrays_after_valid) { |now, before| expect(now).to be(before) }
  end

  # ---- Cached factories ----

  def nested_code_child_class
    @_nested_code_child_class ||= child_class do
      validates :country do
        validates :code, length: { min: 2 }, format: { with: /\AUS\z/ }
      end
    end
  end

  def literal_child_class
    @_literal_child_class ||= child_class { validates :'{:country=>:code}', presence: true }
  end

  let(:length_error) { "does not match the length options: {:min=>2}" }
  let(:format_error) { "does not match the pattern: /\\AUS\\z/" }

  # =====================================================================
  # 1. Recorded wrapper handling
  # =====================================================================

  context "recorded wrapper handling" do
    it "strips a matching Symbol leading name from a recorded path under a synthetic wrapper" do
      child_errs = errors_for([:country, :code] => 'm')
      child_klass = prepared_child(child_errs)
      child_before = Marshal.dump(child_errs)
      parent = parent_for(child_klass, nested: true)

      parent.valid?(address: { country: '' })

      expect(child_klass.instances.last.received).to eq(country: '')
      expect(parent.errors.on([:address, :country, :code])).to eq(['m'])
      expect(parent.errors.on([:address, :country, :country, :code])).to be_nil
      expect(parent.errors.count).to eq(1)
      expect(Marshal.dump(child_errs)).to eq(child_before)
    end

    it "strips a matching String leading name from a recorded path under a synthetic wrapper" do
      child_klass = prepared_child(errors_for(['country', :code] => 'm'))
      parent = parent_for(child_klass, nested: true)

      parent.valid?(address: { country: '' })

      expect(child_klass.instances.last.received).to eq(country: '')
      # The parent's attribute [:address, :country] uses Symbol :country;
      # the child's String 'country' was the wrapper name that got stripped.
      expect(parent.errors.on([:address, :country, :code])).to eq(['m'])
      expect(parent.errors.count).to eq(1)
    end

    it "preserves a non-matching recorded leading name" do
      child_klass = prepared_child(errors_for([:other, :code] => 'm'))
      parent = parent_for(child_klass, nested: true)

      parent.valid?(address: { country: '' })

      expect(child_klass.instances.last.received).to eq(country: '')
      expect(parent.errors.on([:address, :country, :other, :code])).to eq(['m'])
      expect(parent.errors.count).to eq(1)
    end
  end

  # =====================================================================
  # 2. Real repeated names (unwrapped)
  # =====================================================================

  context "real repeated names" do
    it "preserves a child's real leading name when no wrapper was supplied, even when it equals the parent's last name" do
      child = Class.new do
        include PoroValidator.validator
        validates :country do
          validates :code, presence: true
        end
      end
      parent = parent_for(child, nested: true)
      direct = Class.new do
        include PoroValidator.validator
        validates :address do
          validates :country do
            validates :country do
              validates :code, presence: true
            end
          end
        end
      end.new

      payload = { address: { country: { country: { code: nil } } } }
      parent.valid?(payload)
      direct.valid?(payload)

      expect(parent.errors.store.data).to eq(direct.errors.store.data)
      expect(parent.errors.on([:address, :country, :country, :code])).to eq(['is not present'])
      expect(parent.errors.on([:address, :country, :code])).to be_nil
    end
  end

  # =====================================================================
  # 3. Restored and frozen child stores
  # =====================================================================

  context "restored and frozen stores" do
    [false, true].each do |frozen|
      it "composes a #{frozen ? 'deep-frozen' : 'normally-restored'} Marshal child without mutation" do
        original = errors_for(['country', :code] => 'm')
        restored = marshal_roundtrip(original, freeze: frozen)
        before_dump = Marshal.dump(restored)
        store = restored.store
        paths = store.instance_variable_get(:@paths)
        before_flags = if paths
          [paths.frozen?, *paths.values.flat_map { |p| [p.frozen?, *p.map(&:frozen?)] }]
        end

        before_data = restored.store.data
        before_data_id = before_data.object_id
        before_array_ids = before_data.values.map(&:object_id)
        before_message_ids = before_data.values.flatten.map(&:object_id)

        child_klass = prepared_child(restored)
        parent = parent_for(child_klass)

        parent.valid?(address: {})

        expect(parent.errors.on([:address, 'country', :code])).to eq(['m'])
        expect(parent.errors.count).to eq(1)
        expect(restored.store.data.object_id).to eq(before_data_id)
        expect(restored.store.data.values.map(&:object_id)).to eq(before_array_ids)
        expect(restored.store.data.values.flatten.map(&:object_id)).to eq(before_message_ids)
        expect(Marshal.dump(restored)).to eq(before_dump)
        if paths
          after_flags = [paths.frozen?, *paths.values.flat_map { |p| [p.frozen?, *p.map(&:frozen?)] }]
          expect(after_flags).to eq(before_flags)
        end
      end
    end

    it "repeatedly validates a frozen child without changing its state" do
      child_klass = child_class(freeze: true) do
        validates :country do
          validates :code, length: { min: 2 }, format: { with: /\AUS\z/ }
        end
      end
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child_klass
      end.new

      results = [{ code: 'x' }, { code: 'US' }, { code: 'x' }].map do |country|
        parent.valid?(address: { country: country })
        [parent.errors.on([:address, :country, :code]), parent.errors.count]
      end

      expect(results).to eq([
        [[length_error, format_error], 2], [nil, 0], [[length_error, format_error], 2]
      ])
      child_klass.instances.each do |ci|
        expect(ci.errors.store.data).to be_frozen
        expect(ci.errors.store.data.values).to all(be_frozen)
        expect_unchanged(ci)
      end
    end

    it "does not mutate child message Arrays during recorded-path transfer" do
      child = nested_code_child_class
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new

      parent.valid?(address: { country: { code: 'x' } })
      child_instance = child.instances.last
      child_data = child_instance.errors.store.data
      child_messages = child_data['{:country=>:code}']

      copied = parent.errors.on([:address, :country, :code])
      expect(copied).not_to be(child_messages)
      expect(copied.map(&:object_id)).to eq(child_messages.map(&:object_id))

      copied << 'added to parent'
      copied.shift

      expect(child_messages).to eq([length_error, format_error])
      expect_unchanged(child_instance)
    end
  end

  # =====================================================================
  # 4. Legacy and loaded fallback
  # =====================================================================

  context "legacy and loaded fallback" do
    it "treats a loaded rendered-key entry as a literal during composition" do
      errors = PoroValidator::Errors.new
      errors.store.load('{:country=>:code}' => ['loaded'])
      child_klass = prepared_child(errors)
      parent = parent_for(child_klass)

      parent.valid?(address: {})

      expect(parent.errors.on([:address, :country, :code])).to be_nil
      expect(parent.errors.on([:address, :'{:country=>:code}'])).to eq(['loaded'])
      expect(parent.errors.count).to eq(1)
    end

    it "composes an old-layout Marshal child store as a literal, not a nested path" do
      store = load_legacy('legacy-store.marshal')
      expect(store.instance_variables).to eq([:@data])

      errors = PoroValidator::Errors.new
      errors.instance_variable_set(:@store, store)
      child_klass = prepared_child(errors)
      parent = parent_for(child_klass)

      parent.valid?(address: {})

      expect(parent.errors.on([:address, :country, :code])).to be_nil
      expect(parent.errors.on([:address, :'{:country=>:code}'])).to eq(['is not present'])
      expect(store.instance_variables).to eq([:@data])
    end
  end

  # =====================================================================
  # 5. Invalidated record through composition
  # =====================================================================

  context "invalidated record through composition" do
    it "stays on literal fallback after a structured write followed by a literal-alias append, then compose" do
      errors = errors_for([:country, :code] => 'm')
      errors.add('{:country=>:code}', 'literal alias')
      expect(errors.store.__path__('{:country=>:code}')).to be_nil

      child_klass = prepared_child(errors)
      parent = parent_for(child_klass)

      parent.valid?(address: {})

      expect(parent.errors.on([:address, :country, :code])).to be_nil
      expect(parent.errors.on([:address, :'{:country=>:code}'])).to eq(['m', 'literal alias'])
      expect(parent.errors.count).to eq(2)
    end
  end

  # =====================================================================
  # 6. Merge grouping and no alias
  # =====================================================================

  context "merge grouping and no alias" do
    it "merges parent and composed messages at one path, groups full_messages by insertion order, has no obsolete alias" do
      child_klass = prepared_child(errors_for([:country, :code] => 'composed'))
      parent = Class.new do
        include PoroValidator.validator
        validates :address do
          validates :country do
            validates :code, presence: { message: 'parent' }
          end
        end
        validates :other, presence: true
        validates :address, with: child_klass
      end.new

      parent.valid?(address: { country: { code: nil } }, other: nil)

      expect(parent.errors.on([:address, :country, :code])).to eq(['parent', 'composed'])
      expect(parent.errors.on([:address, :'{:country=>:code}'])).to be_nil
      expect(parent.errors.on('{:address=>{:country=>:code}}')).to eq(['parent', 'composed'])
      expect(parent.errors.full_messages).to eq([
        '{:address=>{:country=>:code}} parent',
        '{:address=>{:country=>:code}} composed',
        'other is not present'
      ])
      expect(parent.errors.count).to eq(3)
    end

    it "preserves identical duplicate messages from separate rules in merged output" do
      upper = /\A[A-Z]+\z/
      child = child_class do
        validates :country do
          validates :code, format: { with: upper, message: 'must be upper case' }
          validates :code, format: { with: upper, message: 'must be upper case' }
        end
      end
      parent = Class.new do
        include PoroValidator.validator
        validates :address do
          validates :country do
            validates :code, format: { with: upper, message: 'must be upper case' }
          end
        end
        validates :address, with: child
      end.new

      parent.valid?(address: { country: { code: 'x' } })

      expect(parent.errors.on([:address, :country, :code])).
        to eq(['must be upper case', 'must be upper case', 'must be upper case'])
      expect(parent.errors.count).to eq(3)
      expect(parent.errors.store.data.keys).to eq(['{:address=>{:country=>:code}}'])
    end
  end

  # =====================================================================
  # 7. Actual key hooks in the unrecorded fallback branch
  # =====================================================================

  context "key hooks in the unrecorded fallback branch" do
    it "calls to_s then to_sym on a custom String subclass key, exactly as before" do
      log = []
      key_class = Class.new(String) do
        define_method(:to_s) { log << 'to_s'; String.new(self) }
        define_method(:to_sym) { log << 'to_sym'; :code }
      end

      errors = PoroValidator::Errors.new
      errors.store.data[key_class.new('code')] = ['hooked']
      child_klass = prepared_child(errors)
      parent = parent_for(child_klass)

      log.clear
      parent.valid?(address: {})

      expect(log).to eq(%w[to_s to_sym])
      expect(parent.errors.on([:address, :code])).to eq(['hooked'])
    end
  end

  # =====================================================================
  # 8. Core recorded-path transfer
  # =====================================================================

  context "flat parent with nested child" do
    it "transfers Symbol-keyed Hash input under the complete recorded path" do
      child = nested_code_child_class
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new

      expect(parent.valid?(address: { country: { code: 'x' } })).to be(false)
      expect(parent.errors.on([:address, :country, :code])).to eq([length_error, format_error])
      expect(parent.errors.count).to eq(2)
      expect(parent.errors.full_messages).to eq([
        "{:address=>{:country=>:code}} #{length_error}",
        "{:address=>{:country=>:code}} #{format_error}"
      ])
    end

    it "transfers String-keyed Hash input under the complete recorded path" do
      child = nested_code_child_class
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new

      expect(parent.valid?('address' => { 'country' => { 'code' => 'x' } })).to be(false)
      expect(parent.errors.on([:address, :country, :code])).to eq([length_error, format_error])
      expect(parent.errors.count).to eq(2)
    end

    it "transfers object input under the complete recorded path" do
      child = nested_code_child_class
      obj_country = Struct.new(:code)
      obj_address = Struct.new(:country)
      obj_root = Struct.new(:address)
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new

      expect(parent.valid?(obj_root.new(obj_address.new(obj_country.new('x'))))).to be(false)
      expect(parent.errors.on([:address, :country, :code])).to eq([length_error, format_error])
      expect(parent.errors.count).to eq(2)
    end

    it "records the resulting path for further composition" do
      child = nested_code_child_class
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new
      parent.valid?(address: { country: { code: 'x' } })

      recorded = parent.errors.store.__path__('{:address=>{:country=>:code}}')
      expect(recorded).to eq([:address, :country, :code])
    end
  end

  context "nested parent with nested child" do
    it "prepends the complete parent prefix to the recorded child path" do
      child = nested_code_child_class
      parent = Class.new do
        include PoroValidator.validator
        validates :customer do
          validates :address, with: child
        end
      end.new

      expect(parent.valid?(customer: { address: { country: { code: 'x' } } })).to be(false)
      expect(parent.errors.on([:customer, :address, :country, :code])).
        to eq([length_error, format_error])
      expect(parent.errors.count).to eq(2)
    end
  end

  context "two composition boundaries" do
    it "preserves the correct path, count, messages and nonmutation at each actual level" do
      child = nested_code_child_class
      parent_instances = []
      parent_class = Class.new do
        include PoroValidator.validator
        validates :address, with: child
        define_method(:initialize) { parent_instances << self }
      end
      gp = Class.new do
        include PoroValidator.validator
        validates :order, with: parent_class
      end.new

      gp.valid?(order: { address: { country: { code: 'x' } } })

      expect(gp.errors.on([:order, :address, :country, :code])).
        to eq([length_error, format_error])
      expect(gp.errors.count).to eq(2)
      expect(gp.errors.full_messages).to eq([
        "{:order=>{:address=>{:country=>:code}}} #{length_error}",
        "{:order=>{:address=>{:country=>:code}}} #{format_error}"
      ])

      actual_parent = parent_instances.last
      expect(actual_parent.errors.on([:address, :country, :code])).
        to eq([length_error, format_error])
      expect(actual_parent.errors.count).to eq(2)

      # Validate that repeated use of the intermediate parent is unaffected
      actual_parent.valid?(address: { country: { code: 'US' } })
      expect(actual_parent.errors.count).to eq(0)
      actual_parent.valid?(address: { country: { code: 'x' } })
      expect(actual_parent.errors.on([:address, :country, :code])).
        to eq([length_error, format_error])
    end
  end

  # =====================================================================
  # 9. Literal attribute
  # =====================================================================

  context "literal Ruby-looking attribute" do
    it "is preserved as one segment and never reinterpreted" do
      child = literal_child_class
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new

      parent.valid?(address: {})

      expect(parent.errors.on([:address, :'{:country=>:code}'])).to eq(['is not present'])
      expect(parent.errors.on([:address, :country, :code])).to be_nil
      expect(parent.errors.store.data.keys).to eq(['{:address=>:"{:country=>:code}"}'])
      expect(parent.errors.count).to eq(1)
    end

    it "is preserved through two composition boundaries" do
      child = literal_child_class
      parent_class = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end
      parent = parent_class.new
      gp = Class.new do
        include PoroValidator.validator
        validates :order, with: parent_class
      end.new

      gp.valid?(order: { address: {} })

      expect(gp.errors.on([:order, :address, :'{:country=>:code}'])).to eq(['is not present'])
      expect(gp.errors.count).to eq(1)
    end
  end

  # =====================================================================
  # 10. Foreign store
  # =====================================================================

  context "foreign store" do
    it "does not call __path__ on a store that coincidentally defines it" do
      foreign = Class.new do
        def data
          { 'code' => ['foreign message'] }
        end

        def __path__(text)
          raise '__path__ must not be called on a foreign store'
        end
      end.new

      child_class_local = Class.new do
        include PoroValidator.validator
        define_method(:errors) do
          errors = super()
          errors.instance_variable_set(:@store, foreign)
          errors
        end
      end

      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child_class_local
      end.new

      expect { parent.valid?(address: { code: nil }) }.not_to raise_error
      expect(parent.errors.on([:address, :code])).to eq(['foreign message'])
    end
  end

  # =====================================================================
  # 11. Empty child
  # =====================================================================

  context "empty child" do
    it "contributes nothing and the parent stays valid" do
      child = child_class(after_valid: ->(errors) { errors.store.set('{:country=>:code}', []) }) do
        validates :country do
          validates :code, length: { min: 2 }
        end
      end
      parent = Class.new do
        include PoroValidator.validator
        validates :address, with: child
      end.new

      expect(parent.valid?(address: { country: { code: 'US' } })).to be(true)
      expect(parent.errors.count).to eq(0)
      expect(parent.errors.store.data).to eq({})
    end
  end
end
