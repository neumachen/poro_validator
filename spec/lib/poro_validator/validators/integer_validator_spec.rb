require 'spec_helper'

RSpec.describe PoroValidator::Validators::IntegerValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :amount, integer: true
        validates :rate, integer: true, if: proc { false }
      end.new
    end

    ["aa", 5.00, "+500.00", -1.0, +30.00, "-300.00", "+400.00"].each do |value|
      expect_validator_to_be_invalid("invalid value: #{value}") do
        let(:entity) do
          OpenStruct.new(
            amount: value,
            rate: value
          )
        end

        let(:expected_errors) do
          {
            "amount" => ["is not an integer"]
          }
        end

        skip_attr_unmet_condition do
          let(:attr) { :rate }
        end
      end
    end

    [5, "500", -1, +3000000, "-300", "+400"].each do |value|
      expect_validator_to_be_valid("valid value: #{value}") do
        let(:entity) do
          OpenStruct.new(
            amount: value
          )
        end
      end
    end
  end
end
