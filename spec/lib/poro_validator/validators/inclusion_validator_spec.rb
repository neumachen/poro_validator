require 'spec_helper'

RSpec.describe PoroValidator::Validators::InclusionValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :amount, inclusion: 1..10
        validates :tier, inclusion: [1,2,3,4,5]
        validates :rate, inclusion: 1..10, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          amount: 11,
          tier: 6,
          rate: 11
        )
      end

      let(:expected_errors) do
        {
          "amount" => ["is not within the range of 1..10"],
          "tier"   => ["is not within the range of [1, 2, 3, 4, 5]"]
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

              validates :amount, inclusion: "hello"
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

              validates :amount, inclusion: { in: "hello" }
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
          amount: 5,
          tier: 3
        )
      end
    end
  end

  describe "error messages for options that contain themselves or define #inspect" do
    let(:entity) { OpenStruct.new(tier: :missing) }

    def validator_for(choices)
      Class.new do
        include PoroValidator.validator

        validates :tier, inclusion: { in: choices }
      end.new
    end

    it "reports an array that contains itself" do
      choices = [1]
      choices << choices
      validator = validator_for(choices)

      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on(:tier)).to eq(
        ["is not within the range of [1, [...]]"]
      )
    end

    it "reports an array holding a hash that contains itself" do
      choice = {}
      choice[:self] = choice
      validator = validator_for([choice])

      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on(:tier)).to eq(
        ["is not within the range of [{:self=>{...}}]"]
      )
    end

    it "uses the options' own #inspect" do
      choices = Class.new(::Array) do
        def inspect
          "<custom choices>"
        end
      end.new([1, 2])
      validator = validator_for(choices)

      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on(:tier)).to eq(
        ["is not within the range of <custom choices>"]
      )
    end
  end
end
