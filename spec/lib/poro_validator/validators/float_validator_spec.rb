require 'spec_helper'

RSpec.describe PoroValidator::Validators::FloatValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :amount, float: true
        validates :rate, float: true, if: proc { false }
      end.new
    end

    [5, "500", -1, "+3,000", ".5",
     "-300", "+400", "aaa"].each do |value|
      expect_validator_to_be_invalid("value invalid: #{value}") do
        let(:entity) do
          OpenStruct.new(
            amount: value,
            rate: value
          )
        end

        let(:expected_errors) do
          {
            "amount" => ["is not a float"]
          }
        end

        skip_attr_unmet_condition do
          let(:attr) { :rate }
        end
      end
    end

    [5.00, "500.00", -1.00, "+3,000.000", 0.5, "0.5",
     "-300.00", "+400.00"].each do |value|
      expect_validator_to_be_valid("value value: #{value}") do
        let(:entity) do
          OpenStruct.new(
            amount: value
          )
        end
      end
    end
  end
end
