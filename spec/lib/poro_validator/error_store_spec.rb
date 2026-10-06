require 'spec_helper'

RSpec.describe PoroValidator::ErrorStore do
  describe "#initialize" do
    context "if no data is loaded" do
      it "returns an empty hash" do
        store = described_class.new
        expect(store.data).to eq({})
      end
    end

    context "if data is loaded" do
      it "returns the passed data" do
        data = { "key" => "foo" }
        store = described_class.new(data)
        expect(store.data).to eq(data)
      end
    end
  end

  describe "#get" do
    let(:store) { described_class.new }

    context "if the key is valid" do
      it "returns a value if set" do
        store.set("name", "foo")
        expect(store.get("name")).to eq("foo")
      end

      it "returns nil if the value is not set" do
        expect(store.get("name")).to be_nil
      end
    end

    context "if the key is not valid" do
      it "raises TypeError exception" do
        expect { store.get(1) }.to raise_error(
          ::PoroValidator::InvalidType
        )
      end
    end
  end

  describe "#set" do
    let(:store) { described_class.new }
    let(:key)   { "foo" }
    let(:val)   { "fam" }

    context "if the key is valid" do
      it "does not raise a TypeError exception" do
        expect { store.set(key, val) }.to_not raise_error
      end

      context "and the key has a value given" do
        it "sets a key with the given value" do
          store.set(key, val)
          expect(store.get(key)).to eq(val)
        end
      end

      context "and the key has no valie given" do
        it "sets the key's value to nil" do
          store.set(key)
          expect(store.get(key)).to be_nil
        end
      end

      context "and a block is passed is as a value" do
        it "sets the value from the given block" do
          store.set(key, val) { "block_val" }
          expect(store.get(key)).to_not eq(val)
          expect(store.get(key)).to eq("block_val")
        end
      end
    end

    context "if the key is not valid" do
      it "raises a TypeError exception" do
        expect { store.set(1, val) }.to raise_error(
          ::PoroValidator::InvalidType
        )
      end
    end
  end

  describe "#set?" do
    let(:store) { described_class.new }
    let(:key)   { "foo" }
    let(:val)   { "fam" }

    before(:each) do
      store.set(key, val)
    end

    context "if a key has already been set" do
      it "returns true" do
        expect(store.set?(key)).to be_truthy
      end
    end

    context "if the key has not been set" do
      it "returns false" do
        expect(store.set?("banana")).to be_falsey
      end
    end

    context "if the key is not valid" do
      it "raises a TypeError exception" do
        expect { store.set?(1) }.to raise_error(
          ::PoroValidator::InvalidType
        )
      end
    end
  end

  describe "nested attribute keys" do
    let(:store) { described_class.new }

    it "stores them as {:key=>value} text on every Ruby version" do
      store.set([:address, :line1], ["is not present"])

      expect(store.data.keys).to eq(["{:address=>:line1}"])
      expect(store.get({ address: :line1 })).to eq(["is not present"])
      expect(store.get("{:address=>:line1}")).to eq(["is not present"])
    end

    it "stores a hash key that contains itself and finds it again" do
      key = {}
      key[:self] = key

      store.set(key, ["is not valid"])

      expect(store.data.keys).to eq(["{:self=>{...}}"])
      expect(store.get(key)).to eq(["is not valid"])
      expect(store.set?(key)).to be(true)
      expect(store.get("{:self=>{...}}")).to eq(["is not valid"])
    end
  end

  describe "Array paths" do
    let(:store) { described_class.new }

    it "finds what #set wrote, by the same or an equal Array" do
      path = [:address, :line1]
      value = ["first"]
      store.set(path, value)
      store.set([:address, :city]) { ["from a block"] }

      expect(store.data.keys).to eq(["{:address=>:line1}", "{:address=>:city}"])
      expect(store.get(path)).to be(value)
      expect(store.get([:address, :line1])).to be(value)
      expect(store.set?(path)).to be(true)
      expect(store.set?([:address, :line1])).to be(true)
      expect(store.get({ address: :line1 })).to be(value)
      expect(store.get("{:address=>:line1}")).to be(value)
      expect(store.get([:address, :city])).to eq(["from a block"])
    end

    it "keeps the key #set writes for each shape, and reads it back" do
      {
        [] => "",
        [:name] => "name",
        [:address, :line1] => "{:address=>:line1}",
        [:address, [:country, :code]] => "{:address=>{:country=>:code}}"
      }.each do |path, stored|
        store = described_class.new
        store.set(path, ["value"])

        expect(store.data.keys).to eq([stored]), "key written for #{path.inspect}"
        expect(store.get(path)).to eq(["value"]), "get #{path.inspect}"
        expect(store.set?(path)).to be(true), "set? #{path.inspect}"
      end
    end

    it "reads a path through any nesting that flattens to it, leaving frozen keys alone" do
      path = [:address, [:country, :code].freeze].freeze
      store.set(path, ["value"])

      [path, [:address, :country, :code], [[:address], [:country, :code]]].each do |same_path|
        expect(store.get(same_path)).to eq(["value"]), "get #{same_path.inspect}"
      end
      expect(path).to eq([:address, [:country, :code]])
      expect(path).to be_frozen
      expect(path.last).to be_frozen
    end

    context "with entries #load wrote or older keys use" do
      it "still reads Array-shaped keys from #load and from literal text, unchanged" do
        value = ["loaded"]
        loaded = described_class.new({ [:address, :line1] => value })
        literal = described_class.new({ "[:address, :line1]" => value })

        [loaded, literal].each do |store|
          expect(store.data.keys).to eq(["[:address, :line1]"])
          expect(store.get([:address, :line1])).to be(value)
          expect(store.set?([:address, :line1])).to be(true)
          expect(store.get("[:address, :line1]")).to be(value)
        end
      end

      it "prefers the entry #set writes, even when its value is nil or false" do
        [["current"], nil, false].each do |current|
          legacy = ["legacy"]
          store = described_class.new(
            "[:address, :line1]" => legacy, "{:address=>:line1}" => current
          )

          expect(store.get([:address, :line1])).to be(current)
          expect(store.set?([:address, :line1])).to be(true)
          expect(store.get("[:address, :line1]")).to be(legacy)
          expect(store.get("{:address=>:line1}")).to be(current)
        end
      end

      it "finds nothing when neither entry exists" do
        expect(store.get([:address, :line1])).to be_nil
        expect(store.set?([:address, :line1])).to be(false)
      end
    end

    context "with a recursive Array" do
      let(:recursive) { [].tap { |array| array << array } }

      it "still reads an entry #load wrote for it, and finds nothing without one" do
        loaded = described_class.new({ recursive => ["cycle"] })

        expect(loaded.data.keys).to eq(["[[...]]"])
        expect(loaded.get(recursive)).to eq(["cycle"])
        expect(loaded.set?(recursive)).to be(true)
        expect(store.get(recursive)).to be_nil
        expect(store.set?(recursive)).to be(false)
      end

      it "still can't be written by #set" do
        expect { store.set(recursive, ["new"]) }.
          to raise_error(ArgumentError, "tried to flatten recursive array")
      end
    end
  end

  describe "#reset" do
    let(:store) { described_class.new }

    it "clears the data stored" do
      store.set(:foo, "foo")
      expect(store.get(:foo)).to eq("foo")
      expect(store.reset).to eq({})
    end
  end
end
