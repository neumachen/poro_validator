require 'spec_helper'

RSpec.describe PoroValidator::Utils::DeepSymbolizeKeys, type: :utils do
  describe ".call" do
    let(:unsymbolized_hash) do
      {
        "first_name" => "manbearpig",
        "last_name" => "gore",
        "dob" => "01/01/1977",
        "phone_numbers" => ["33333", "44444"],
        "address" => {
          "line1" => "foo",
          "line2" => "boo"
        }
      }
    end

    let(:symbolized_hash) do
      {
        first_name: "manbearpig",
        last_name: "gore",
        dob: "01/01/1977",
        phone_numbers: ["33333", "44444"],
        address: {
          line1: "foo",
          line2: "boo"
        }
      }
    end

    it "symbolizes all non-symbol keys in a hash, including nested hashes" do
      expect(described_class.call(unsymbolized_hash)).to eq(symbolized_hash)
    end

    it "does not require the input to respond to the method itself" do
      # No #extend and no global Hash#deep_symbolize_keys/#deep_transform_keys
      # are involved: .call is a plain module function, usable on any Hash.
      expect(({}).respond_to?(:deep_symbolize_keys)).to be(false)
      expect(({}).respond_to?(:deep_transform_keys)).to be(false)
      expect(described_class.call({"a" => 1})).to eq({a: 1})
    end

    it "works on a frozen root hash and frozen nested hashes without mutation" do
      frozen = { "address" => { "line1" => "x" }.freeze }.freeze
      result = described_class.call(frozen)
      expect(result).to eq({ address: { line1: "x" } })
      expect(frozen.frozen?).to be(true)
      expect(frozen["address"].frozen?).to be(true)
      expect(result.frozen?).to be(false)
    end

    it "leaves a key unchanged when #to_sym raises" do
      key = Object.new
      def key.to_sym
        raise NoMethodError, "no to_sym"
      end
      result = described_class.call({ key => "value" })
      expect(result).to eq({ key => "value" })
      expect(result.keys.first).to be(key)
    end

    it "keeps the later key's value when a String and Symbol form of the same key collide, following source insertion order" do
      string_first = described_class.call({ "name" => "a", name: "b" })
      symbol_first = described_class.call({ name: "b", "name" => "a" })
      expect(string_first).to eq({ name: "b" })
      expect(symbol_first).to eq({ name: "a" })
    end

    it "does not normalize or copy an Array, or a Hash found inside an Array" do
      array = [{ "a" => 1 }]
      result = described_class.call({ "tags" => array })
      expect(result).to eq({ tags: [{ "a" => 1 }] })
      expect(result[:tags]).to be(array)             # same Array object, not copied
      expect(result[:tags].first).to be(array.first)  # same inner Hash, keys untouched
    end

    it "preserves insertion order of the resulting keys" do
      result = described_class.call({ "b" => 1, "a" => 2 })
      expect(result.keys).to eq([:b, :a])
    end
  end
end
