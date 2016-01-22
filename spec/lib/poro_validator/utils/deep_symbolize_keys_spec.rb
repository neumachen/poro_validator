require 'spec_helper'

RSpec.describe PoroValidator::Utils::DeepSymbolizeKeys, type: :utils do
  describe ::Hash do
    describe "#deep_symbolize_keys" do
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

      it "symbolizes all non symbol keys in a hash" do
        unsymbolized_hash.extend(::PoroValidator::Utils::DeepSymbolizeKeys)
        expect(unsymbolized_hash.deep_symbolize_keys).to eq(
          symbolized_hash
        )
      end
    end
  end
end
