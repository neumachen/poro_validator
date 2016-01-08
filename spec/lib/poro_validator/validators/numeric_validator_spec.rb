require 'spec_helper'

RSpec.describe PoroValidator::Validators::NumericValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :section, numeric: 1..10
        validates :amount, numeric: 1..10
        validates :cap, numeric: { extremum: 5 }
        validates :bonus, numeric: { min: 10, max: 20 }
        validates :price, numeric: { min: 10 }
        validates :interest, numeric: { max: 20 }
        validates :rate, numeric: 1..10, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          section: 'aa',
          amount: 11,
          cap: 6,
          bonus: 21,
          price: 9,
          interest: 21,
          rate: 11
        )
      end

      let(:expected_errors) do
        {
          "section"  => ["is not an integer"],
          "amount"   => ["does not match the numeric options: {:in=>1..10}"],
          "cap"      => ["does not match the numeric options: {:extremum=>5}"],
          "bonus"    => ["does not match the numeric options: {:max=>20}"],
          "price"    => ["does not match the numeric options: {:min=>10}"],
          "interest" => ["does not match the numeric options: {:max=>20}"],
        }
      end

      skip_attr_unmet_condition do
        let(:attr) { :rate }

        it "expects the attribute is not valid" do
          expect(entity.public_send(attr).between?(1, 10)).to be_falsey
        end
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          section: 1,
          amount: 10,
          cap: 5,
          bonus: 11,
          price: 11,
          interest: 19,
          rate: 11
        )
      end
    end
  end
end
