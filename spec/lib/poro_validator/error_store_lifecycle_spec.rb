require 'spec_helper'

# Behavior an ErrorStore keeps whatever it records internally: returns, the
# order of the work callers can observe, exceptions, stores dumped by the
# unmodified gem, and that nothing outside #data keeps messages the store no
# longer holds. Written for the structured-path prototype; every example also
# holds for the unmodified gem.
RSpec.describe PoroValidator::ErrorStore, "lifecycle", :aggregate_failures do
  let(:fixtures) { File.expand_path('../../fixtures/legacy', __dir__) }

  # Every object reachable from the store's instance variables other than
  # @data, following Hash keys and values and Array elements.
  def retained_outside_data(store)
    seen = {}.compare_by_identity
    pending = (store.instance_variables - [:@data]).map { |name| store.instance_variable_get(name) }
    until pending.empty?
      object = pending.pop
      next if seen.key?(object)

      seen[object] = true
      case object
      when Hash then object.each { |key, value| pending << key << value }
      when Array then pending.concat(object)
      end
    end
    seen.keys
  end

  def retains?(store, object)
    retained_outside_data(store).any? { |retained| retained.equal?(object) }
  end

  def load_fixture(name, **options)
    Marshal.load(File.binread(File.join(fixtures, name)), **options)
  end

  # An object whose listed methods log [label, name] and return the value.
  def recorder(log, label, returns)
    object = Object.new
    returns.each do |name, value|
      object.define_singleton_method(name) do |*|
        log << [label, name]
        value
      end
    end
    object
  end

  def with_messages(messages)
    PoroValidator.configure do |config|
      messages.each { |name, message| config.message.set(name, message) }
    end
    yield
  ensure
    PoroValidator.configure { |config| config.message.instance_variable_set(:@messages, {}) }
  end

  describe "#set" do
    it "renders the key, then runs the block, then writes" do
      log = []
      store = described_class.new
      segment = recorder(log, :segment, inspect: ":seg")

      returned = store.set([:a, segment]) { log << [:block, :yield]; ["m"] }

      expect(log).to eq([[:segment, :inspect], [:block, :yield]])
      expect(returned).to eq(["m"])
      expect(store.data).to eq("{:a=>:seg}" => ["m"])
    end

    it "writes to the Hash it read before the block, even if the block resets the store" do
      store = described_class.new

      expect(store.set([:a, :b]) { store.reset; ["m"] }).to eq(["m"])
      expect(store.data).to eq({})
    end

    it "lets the block make the key recursive after it was rendered" do
      store = described_class.new
      path = [:a, :b]

      expect(store.set(path) { path << path; ["message"] }).to eq(["message"])
      expect(store.data).to eq("{:a=>:b}" => ["message"])
    end

    it "converts an element with to_ary once" do
      calls = 0
      convertible = Object.new
      convertible.define_singleton_method(:to_ary) do
        calls += 1
        raise "converted again" if calls > 1
        [:b]
      end
      store = described_class.new

      store.set([:a, convertible], ["message"])

      expect(calls).to eq(1)
      expect(store.data).to eq("{:a=>:b}" => ["message"])
    end

    it "returns the value, or the block's value" do
      store = described_class.new
      value = ["m"]

      expect(store.set([:a, :b], value)).to be(value)
      expect(store.set(:c) { value }).to be(value)
    end

    it "raises in the same order as before and writes nothing" do
      store = described_class.new
      block_ran = false
      recursive = [:a]
      recursive << recursive

      expect { store.set(1) { block_ran = true } }.to raise_error(PoroValidator::InvalidType)
      expect { store.set(recursive) { block_ran = true } }.
        to raise_error(ArgumentError, "tried to flatten recursive array")
      expect { store.set([:a, :b]) { raise KeyError, "block failed" } }.to raise_error(KeyError, "block failed")
      expect(block_ran).to be(false)
      expect(store.data).to eq({})

      store.data.freeze
      expect { store.set([:a, :b], ["m"]) }.to raise_error(FrozenError)
      expect(store.data).to eq({})
    end
  end

  describe "Errors#add" do
    it "renders an existing key twice before building the message, and returns the stored Array" do
      log = []
      errors = PoroValidator::Errors.new
      segment = recorder(log, :segment, inspect: ":b")
      errors.store.set([:a, segment], ["first"])
      log.clear

      returned = with_messages(lifecycle_second: -> { log << [:message, :call]; "second" }) do
        errors.add([:a, segment], :lifecycle_second)
      end

      expect(log).to eq([[:segment, :inspect], [:segment, :inspect], [:message, :call]])
      expect(returned).to eq(["first", "second"])
      expect(returned).to be(errors.store.data["{:a=>:b}"])
    end

    it "appends nothing when building the message fails" do
      errors = PoroValidator::Errors.new
      errors.add([:a, :b], "first")

      with_messages(lifecycle_failing: -> { raise "message failed" }) do
        expect { errors.add([:a, :b], :lifecycle_failing) }.to raise_error(RuntimeError, "message failed")
      end
      expect(errors.store.data).to eq("{:a=>:b}" => ["first"])
    end

    it "appends to one messages Array shared by two keys, as before" do
      errors = PoroValidator::Errors.new
      shared = ["first"]
      errors.store.set([:a, :b], shared)
      errors.store.set("{:c=>:d}", shared)

      errors.add([:a, :b], "second")

      expect(errors.store.data).to eq("{:a=>:b}" => ["first", "second"], "{:c=>:d}" => ["first", "second"])
      expect(errors.store.data.values.first).to be(errors.store.data.values.last)
    end
  end

  describe "messages the store no longer holds" do
    retirements = {
      "set replaces them" => ->(store, text) { store.set([:a, :b], ["replacement"]) },
      "load replaces them" => ->(store, text) { store.load(text => ["replacement"]) },
      "a raw delete removes them" => ->(store, text) { store.data.delete(text) },
      "a raw clear removes them" => ->(store, _text) { store.data.clear },
      "a raw replace removes them" => ->(store, text) { store.data.replace(text => ["replacement"]) }
    }

    retirements.each do |label, retire|
      it "are not kept and do not stop Marshal.dump when #{label}" do
        store = described_class.new
        retired = [proc {}]
        store.set([:a, :b], retired)

        retire.call(store, store.data.keys.first)

        expect(store.data.values.none? { |value| value.equal?(retired) }).to be(true)
        expect(retains?(store, retired)).to be(false)
        expect { Marshal.dump(store) }.not_to raise_error
      end
    end

    it "are not kept across successive overwrites, and nothing grows" do
      store = described_class.new
      arrays = Array.new(50) { |index| ["message #{index}"] }
      store.set([:a, :b], arrays.first)
      after_one = retained_outside_data(store).size

      arrays.drop(1).each { |messages| store.set([:a, :b], messages) }

      expect(store.data).to eq("{:a=>:b}" => arrays.last)
      expect(retained_outside_data(store).size).to eq(after_one)
      expect(arrays.none? { |messages| retains?(store, messages) }).to be(true)
    end
  end

  describe "stores dumped by the unmodified gem" do
    it "read as before, frozen or not" do
      store = load_fixture("legacy-store.marshal")
      deep = load_fixture("legacy-store.marshal", freeze: true)

      [store, deep].each do |restored|
        expect(restored.instance_variables).to eq([:@data])
        expect(restored.data).to eq(
          "{:country=>:code}" => ["is not present"], "name" => ["is not present"], "literal" => ["is a literal"]
        )
        expect(restored.get([:country, :code])).to eq(["is not present"])
        expect(restored.set?(:name)).to be(true)
      end
      expect(deep).to be_frozen
      expect { deep.set(:x, ["n"]) }.to raise_error(FrozenError)
      expect(deep.instance_variables).to eq([:@data])
    end

    it "take writes as before, without gaining instance variables" do
      store = load_fixture("legacy-store.marshal")
      store.set([:a, :b], ["m"])
      store.load("x" => ["y"])
      expect(store.get([:a, :b])).to eq(["m"])
      expect(store.instance_variables).to eq([:@data])
      expect(store.reset).to eq({})
      expect(store.instance_variables).to eq([:@data])

      shallow = load_fixture("legacy-store.marshal").freeze
      expect(shallow.set([:a, :b], ["m"])).to eq(["m"])
      expect { shallow.reset }.to raise_error(FrozenError)
      expect(shallow.instance_variables).to eq([:@data])
    end

    it "include Errors that still take messages" do
      errors = load_fixture("legacy-errors.marshal")

      errors.add([:address, [:country, :code]], "is still not present")
      errors.add([:address, :line1], "is not present")

      expect(errors.on([:address, :country, :code])).to eq(["is not present", "is still not present"])
      expect(errors.full_messages).to eq([
        "{:address=>{:country=>:code}} is not present",
        "{:address=>{:country=>:code}} is still not present",
        "name is not present",
        "{:address=>:line1} is not present"
      ])
      expect(errors.store.instance_variables).to eq([:@data])
    end
  end

  it "reads a deep-frozen store of this version without changing it" do
    store = described_class.new
    store.set([:country, :code], ["m"])
    store.set(:name, ["n"])
    frozen = Marshal.load(Marshal.dump(store), freeze: true)
    variables = frozen.instance_variables

    expect(frozen.get([:country, :code])).to eq(["m"])
    expect(frozen.set?(:name)).to be(true)
    expect(frozen.data).to eq(store.data)
    expect(frozen.instance_variables).to eq(variables)
    expect(frozen).to be_frozen
  end
end
