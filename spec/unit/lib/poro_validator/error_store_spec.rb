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
        expect { store.get(['foo', 'faa']) }.to raise_error(
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

  describe "#reset" do
    let(:store) { described_class.new }

    it "clears the data stored" do
      store.set(:foo, "foo")
      expect(store.get(:foo)).to eq("foo")
      expect(store.reset).to eq({})
    end
  end
end
