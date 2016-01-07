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

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          amount: "aaa",
          rate: "aaa"
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

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          amount: 5
        )
      end
    end
  end
end
