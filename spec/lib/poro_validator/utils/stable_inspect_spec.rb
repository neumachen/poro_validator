require 'spec_helper'

RSpec.describe PoroValidator::Utils::StableInspect, type: :utils do
  describe ".call" do
    it "renders a hash with the pre-3.4 Hash#inspect syntax" do
      expect(described_class.call({ in: 1..10 })).to eq("{:in=>1..10}")
    end

    it "renders nested hashes" do
      expect(described_class.call({ address: { country: :code } })).to eq(
        "{:address=>{:country=>:code}}"
      )
    end

    it "renders string keys and several pairs" do
      expect(described_class.call({ "min" => 1, max: 2**64 })).to eq(
        "{\"min\"=>1, :max=>18446744073709551616}"
      )
    end

    it "renders hashes inside arrays" do
      expect(described_class.call([:a, { b: 1 }])).to eq("[:a, {:b=>1}]")
    end

    it "uses #inspect for other values" do
      expect(described_class.call(1...10)).to eq("1...10")
      expect(described_class.call(/\d+/)).to eq("/\\d+/")
      expect(described_class.call("text")).to eq("\"text\"")
    end
  end
end
