require 'spec_helper'

RSpec.describe PoroValidator::Validators::ExclusionValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :amount, exclusion: 5..10
        validates :tier, exclusion: [1,2,3,4,5]
        validates :rate, exclusion: 5..10, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          amount: 6,
          tier: 5,
          rate: 5
        )
      end

      let(:expected_errors) do
        {
          "amount" => ["is not outside the range of 5..10"],
          "tier"   => ["is not outside the range of [1, 2, 3, 4, 5]"]
        }
      end

      skip_attr_unmet_condition do
        let(:attr) { :rate }
      end

      context "validator option is not valid" do
        context "in option is nil" do
          subject(:validator) do
            Class.new do
              include PoroValidator.validator

              validates :amount, exclusion: "hello"
            end.new
          end

          it "raises a ::PoroValidator::InvalidValidator" do
            expect { subject.valid?(entity) }.to raise_error(
              ::PoroValidator::InvalidValidator
            )
          end
        end

        context "not a range or array" do
          subject(:validator) do
            Class.new do
              include PoroValidator.validator

              validates :amount, exclusion: { in: "hello" }
            end.new
          end

          it "raises a ::PoroValidator::InvalidValidator" do
            expect { subject.valid?(entity) }.to raise_error(
              ::PoroValidator::InvalidValidator
            )
          end
        end
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          amount: 4,
          tier: 6
        )
      end
    end
  end
end
