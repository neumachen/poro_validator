require 'spec_helper'

# The structured-path prototype: ErrorStore records the names of an ordinary
# path under the text #set writes for it (#__path__), and every library write
# to that text keeps the record in step. These examples need the prototype.
# Against the unmodified gem they fail: #__path__ and #__append__ are missing.
RSpec.describe PoroValidator::ErrorStore, "path records", :aggregate_failures do
  let(:store) { described_class.new }
  let(:fixtures) { File.expand_path('../../fixtures/legacy', __dir__) }

  def load_fixture(name, **options)
    Marshal.load(File.binread(File.join(fixtures, name)), **options)
  end

  def with_messages(messages)
    PoroValidator.configure do |config|
      messages.each { |name, message| config.message.set(name, message) }
    end
    yield
  ensure
    PoroValidator.configure { |config| config.message.instance_variable_set(:@messages, {}) }
  end

  describe "an ordinary path" do
    it "is recorded under its text as frozen copies of its names" do
      country = String.new("country")
      path = [:address, [country, :code]]

      store.set(path, ["m"])
      names = store.__path__("{:address=>{\"country\"=>:code}}")

      expect(names).to eq([:address, "country", :code])
      expect(names).to be_frozen
      expect(names[1]).to be_frozen
      expect(names[1]).not_to be(country)
      expect(country).not_to be_frozen
      expect(path).not_to be_frozen
    end

    it "is read through nested Arrays of any class" do
      nested = Class.new(Array)[:code]

      store.set([[:country], nested], ["m"])

      expect(store.data.keys).to eq(["{:country=>:code}"])
      expect(store.__path__("{:country=>:code}")).to eq([:country, :code])
    end

    it "keeps String names Strings and Symbol names Symbols" do
      store.set(["country", "code"], ["strings"])
      store.set([:country, :code], ["symbols"])

      expect(store.__path__("{\"country\"=>\"code\"}")).to eq(["country", "code"])
      expect(store.__path__("{:country=>:code}")).to eq([:country, :code])
    end

    it "keeps the names it took before the block, whatever the caller changes" do
      name = String.new("code")
      path = [:country, name]

      store.set(path) { name << "x"; path << :more; ["m"] }
      name << "y"

      expect(store.data.keys).to eq(["{:country=>\"code\"}"])
      expect(store.__path__("{:country=>\"code\"}")).to eq([:country, "code"])
    end

    it "leaves frozen paths and names as they were" do
      path = [:country, "code".dup.freeze].freeze

      store.set(path, ["m"])

      expect(store.__path__("{:country=>\"code\"}")).to eq([:country, "code"])
      expect(path).to eq([:country, "code"])
      expect(path).to be_frozen
      expect(path.last).to be_frozen
    end
  end

  describe "keys that are not recorded" do
    it "include no or one name, literal text, Symbols and Hashes" do
      { [] => "", [:name] => "name", "{:a=>:b}" => "{:a=>:b}", :"{:a=>:b}" => "{:a=>:b}",
        { a: :b } => "{:a=>:b}" }.each do |key, text|
        written = described_class.new
        written.set(key, ["m"])

        expect(written.data.keys).to eq([text]), key.inspect
        expect(written.__path__(text)).to be_nil, key.inspect
      end
    end

    it "include paths holding anything but Arrays, Symbols and plain Strings" do
      subclass_string = Class.new(String).new("code")
      singleton = String.new("code").tap { |name| name.define_singleton_method(:note) { "note" } }
      private_to_ary = String.new("code")
      private_to_ary.define_singleton_method(:to_ary) { [:x, :y] }
      private_to_ary.singleton_class.send(:private, :to_ary)
      inspecting = Object.new.tap { |name| name.define_singleton_method(:inspect) { ":code" } }
      converting = Object.new.tap { |name| name.define_singleton_method(:to_ary) { [:code] } }
      subclass_key = Class.new(Array)[:country, :code]
      singleton_key = [:country, :code].tap { |key| key.define_singleton_method(:flatten) { |*args| super(*args) } }
      shared = [:b]

      [[:country, subclass_string], [:country, singleton], [:country, private_to_ary], [:country, 0],
       [:country, nil], [:country, inspecting], [:country, converting], [:country, { code: :x }],
       subclass_key, singleton_key, [:a, shared, shared]].each do |key|
        written = described_class.new
        written.set(key, ["m"])

        written.data.each_key { |text| expect(written.__path__(text)).to be_nil, text }
      end
    end
  end

  describe "library writes to a recorded text" do
    it "replace or remove the record: set, load and reset" do
      store.set([:a, :b], ["typed"])
      store.set("{:a=>:b}", ["literal"])
      expect(store.__path__("{:a=>:b}")).to be_nil

      store.set([:a, :b], ["typed again"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
      store.set([[:a], :b], ["an equal path"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])

      store.load("{:a=>:b}" => ["loaded"])
      expect(store.__path__("{:a=>:b}")).to be_nil

      store.set([:a, :b], ["typed"])
      store.load([:a, :b] => ["loaded under the Array's own text"])
      expect(store.data.keys).to eq(["{:a=>:b}", "[:a, :b]"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
      expect(store.__path__("[:a, :b]")).to be_nil

      store.reset
      expect(store.__path__("{:a=>:b}")).to be_nil
      store.set([:a, :b], ["after reset"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
    end

    it "keep one record per text, whatever the number of writes" do
      50.times { |index| store.set([:a, :b], ["message #{index}"]) }

      expect(store.instance_variable_get(:@paths)).to eq("{:a=>:b}" => [:a, :b])
    end

    it "go to the records read before the block, even if the block resets the store" do
      store.set([:a, :b]) { store.reset; ["m"] }

      expect(store.data).to eq({})
      expect(store.__path__("{:a=>:b}")).to be_nil
    end

    it "treat one messages Array shared by two keys as two entries" do
      shared = ["m"]
      store.set([:a, :b], shared)
      store.set("{:c=>:d}", shared)

      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
      expect(store.__path__("{:c=>:d}")).to be_nil
    end

    it "forget every record when a key renders to something other than a String" do
      odd = Class.new(Hash) { def inspect = :odd }.new
      odd[:a] = :b
      store.set([:a, :b], ["typed"])

      store.set(odd, ["odd"])

      expect(store.data.keys).to eq(["{:a=>:b}", :odd])
      expect(store.__path__("{:a=>:b}")).to be_nil
    end
  end

  describe "appending through Errors#add" do
    let(:errors) { PoroValidator::Errors.new }

    it "keeps the record for the same path in any nesting" do
      errors.add([:a, :b], "one")
      errors.add([[:a], :b], "two")
      errors.add([:a, [:b]], "three")

      expect(errors.on([:a, :b])).to eq(["one", "two", "three"])
      expect(errors.store.__path__("{:a=>:b}")).to eq([:a, :b])
    end

    it "forgets the record when a message comes through another key, in either order" do
      ["{:a=>:b}", :"{:a=>:b}", { a: :b }].each do |other|
        typed_first = PoroValidator::Errors.new
        typed_first.add([:a, :b], "typed")
        typed_first.add(other, "other")

        other_first = PoroValidator::Errors.new
        other_first.add(other, "other")
        other_first.add([:a, :b], "typed")

        expect(typed_first.on([:a, :b])).to eq(["typed", "other"]), other.inspect
        expect(typed_first.store.__path__("{:a=>:b}")).to be_nil, other.inspect
        expect(other_first.on([:a, :b])).to eq(["other", "typed"]), other.inspect
        expect(other_first.store.__path__("{:a=>:b}")).to be_nil, other.inspect
      end
    end

    it "keeps the record when building the message fails" do
      errors.add([:a, :b], "first")

      with_messages(paths_failing: -> { raise "message failed" }) do
        expect { errors.add("{:a=>:b}", :paths_failing) }.to raise_error(RuntimeError, "message failed")
      end
      expect(errors.store.data).to eq("{:a=>:b}" => ["first"])
      expect(errors.store.__path__("{:a=>:b}")).to eq([:a, :b])
    end

    it "keeps working, without records, for Errors dumped by the unmodified gem" do
      legacy = load_fixture("legacy-errors.marshal")

      legacy.add([:address, [:country, :code]], "is still not present")
      legacy.add([:address, :line1], "is not present")

      expect(legacy.store.__path__("{:address=>{:country=>:code}}")).to be_nil
      expect(legacy.store.__path__("{:address=>:line1}")).to be_nil
      expect(legacy.store.instance_variables).to eq([:@data])
    end
  end

  describe "raw changes to #data" do
    it "are not seen: a record describes its text until a library write replaces it" do
      store.set([:a, :b], ["m"])

      store.data.delete("{:a=>:b}")
      expect(store.data).to eq({})
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])

      store.data["{:a=>:b}"] = ["written raw"]
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])

      store.data["{:x=>:y}"] = store.data.delete("{:a=>:b}")
      expect(store.__path__("{:x=>:y}")).to be_nil

      store.data.clear
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
    end
  end

  describe "what the records hold" do
    it "is frozen copies of texts and names, and no messages" do
      names = [String.new("country"), String.new("code")]
      messages = ["m"]
      store.set(names, messages)
      store.set([:a, :b], ["n"])
      store.set("literal", ["o"])

      records = store.instance_variable_get(:@paths)

      expect(records).to eq("{\"country\"=>\"code\"}" => ["country", "code"], "{:a=>:b}" => [:a, :b])
      records.each do |text, recorded|
        expect(text.class).to be(String)
        expect(text).to be_frozen
        expect(recorded).to be_frozen
        recorded.each do |name|
          expect([String, Symbol]).to include(name.class)
          expect(name).to be_frozen
          expect(names.none? { |original| original.equal?(name) }).to be(true)
        end
        expect(recorded).not_to be(messages)
      end
    end

    it "survives a Marshal round trip, and a deep-frozen copy is only read" do
      store.set([:country, :code], ["m"])

      restored = Marshal.load(Marshal.dump(store))
      frozen = Marshal.load(Marshal.dump(store), freeze: true)

      expect(restored.__path__("{:country=>:code}")).to eq([:country, :code])
      expect(frozen.__path__("{:country=>:code}")).to eq([:country, :code])
      expect(frozen.instance_variables).to eq([:@data, :@paths])
      expect { frozen.set([:a, :b], ["m"]) }.to raise_error(FrozenError)
      expect(frozen.__path__("{:a=>:b}")).to be_nil
    end
  end

  describe "stores dumped by the unmodified gem" do
    it "have no records, never get any, and keep their writes as before" do
      legacy = load_fixture("legacy-store.marshal")

      expect(legacy.__path__("{:country=>:code}")).to be_nil
      legacy.set([:a, :b], ["m"])
      legacy.load("x" => ["y"])
      expect(legacy.__path__("{:a=>:b}")).to be_nil
      expect(legacy.reset).to eq({})
      expect(legacy.instance_variables).to eq([:@data])

      deep = load_fixture("legacy-store.marshal", freeze: true)
      expect(deep.__path__("{:country=>:code}")).to be_nil
      expect(deep.instance_variables).to eq([:@data])
    end
  end

  describe "reading records back" do
    it "gives frozen names from a normally restored store, and reading changes nothing" do
      store.set([:a, "b"], ["message"])
      restored = Marshal.load(Marshal.dump(store))
      records = restored.instance_variable_get(:@paths)
      record = records["{:a=>\"b\"}"]
      frozen_before = [records.frozen?, record.frozen?, record.last.frozen?]

      names = restored.__path__("{:a=>\"b\"}")

      expect(names).to eq([:a, "b"])
      expect(names).to be_frozen
      expect(names.last).to be_frozen
      expect { names.last << "changed" }.to raise_error(FrozenError)
      expect { names << :more }.to raise_error(FrozenError)
      expect(restored.__path__("{:a=>\"b\"}")).to eq([:a, "b"])
      expect(restored.data).to eq("{:a=>\"b\"}" => ["message"])
      expect(restored.instance_variables).to eq([:@data, :@paths])
      expect(restored.instance_variable_get(:@paths)).to be(records)
      expect(records).to eq("{:a=>\"b\"}" => [:a, "b"])
      expect(records["{:a=>\"b\"}"]).to be(record)
      expect(frozen_before).to eq([false, false, false])
      expect([records.frozen?, record.frozen?, record.last.frozen?]).to eq(frozen_before)
    end

    it "gives the frozen record itself from a fresh or a deep-frozen store" do
      store.set([:a, "b"], ["message"])
      deep = Marshal.load(Marshal.dump(store), freeze: true)

      [store, deep].each do |reader|
        names = reader.__path__("{:a=>\"b\"}")

        expect(names).to be(reader.instance_variable_get(:@paths)["{:a=>\"b\"}"])
        expect(names).to be_frozen
        expect(names.last).to be_frozen
        expect { names.last << "changed" }.to raise_error(FrozenError)
        expect(reader.__path__("{:a=>\"b\"}")).to eq([:a, "b"])
      end
    end
  end

  describe "appending through a store whose #get is overridden" do
    let(:super_store) do
      Class.new(described_class) do
        def get(key)
          super
        end
      end
    end

    let(:redirecting_store) do
      Class.new(described_class) do
        def destination
          @destination ||= ["get-owned"]
        end

        def get(key)
          destination
        end
      end
    end

    # Hands out the entry of "{:c=>:d}" whatever the key.
    let(:handing_out_store) do
      Class.new(described_class) do
        def get(key)
          data["{:c=>:d}"]
        end
      end
    end

    let(:failing_store) do
      Class.new(described_class) do
        def get(key)
          raise KeyError, "get failed"
        end
      end
    end

    # An Errors whose store is a new instance of store_class.
    def errors_with(store_class)
      store = store_class.new
      errors_class = Class.new(PoroValidator::Errors) do
        define_method(:initialize) { @store = store }
      end
      [errors_class.new, store]
    end

    it "keeps or forgets the record as the built-in #get does when the override calls super" do
      errors, store = errors_with(super_store)
      errors.add([:a, :b], "one")
      errors.add([[:a], :b], "two")
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])

      errors.add("{:a=>:b}", "three")

      expect(store.__path__("{:a=>:b}")).to be_nil
      expect(store.data).to eq("{:a=>:b}" => ["one", "two", "three"])
    end

    it "changes no record when the override returns an Array from outside the store" do
      errors, store = errors_with(redirecting_store)
      errors.add([:a, :b], "typed")

      errors.add("{:a=>:b}", "through the String alias")

      expect(store.destination).to eq(["get-owned", "through the String alias"])
      expect(store.data).to eq("{:a=>:b}" => ["typed"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
    end

    it "forgets the record of the entry the override hands out when the key names another path" do
      errors, store = errors_with(handing_out_store)
      errors.add([:a, :b], "a-b")
      errors.add([:c, :d], "c-d")

      errors.add([:a, :b], "through [:a, :b]")

      expect(store.data).to eq("{:a=>:b}" => ["a-b"], "{:c=>:d}" => ["c-d", "through [:a, :b]"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
      expect(store.__path__("{:c=>:d}")).to be_nil
    end

    it "keeps the record when the override raises" do
      errors, store = errors_with(failing_store)
      errors.add([:a, :b], "typed")

      expect { errors.add("{:a=>:b}", "through the String alias") }.to raise_error(KeyError, "get failed")

      expect(store.data).to eq("{:a=>:b}" => ["typed"])
      expect(store.__path__("{:a=>:b}")).to eq([:a, :b])
    end
  end

  describe "appending to one messages Array held by several entries" do
    it "forgets the record of each entry whose path the key does not name" do
      errors = PoroValidator::Errors.new
      shared = ["shared"]
      errors.store.set([:a, :b], shared)
      errors.store.set([:c, :d], shared)

      errors.add([:a, :b], "through [:a, :b]")

      expect(errors.store.data).to eq("{:a=>:b}" => ["shared", "through [:a, :b]"],
                                      "{:c=>:d}" => ["shared", "through [:a, :b]"])
      expect(errors.store.__path__("{:a=>:b}")).to eq([:a, :b])
      expect(errors.store.__path__("{:c=>:d}")).to be_nil
    end
  end
end
