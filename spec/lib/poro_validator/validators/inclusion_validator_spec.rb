require 'spec_helper'

RSpec.describe PoroValidator::Validators::InclusionValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :amount, inclusion: 1..10
        validates :rate, inclusion: 1..10, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          amount: 11,
          rate: 11
        )
      end

      let(:expected_errors) do
        {
          "amount" => ["is not within the range of 1..10"]
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
