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
          "section"  => ["is not an integer or float type"],
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

    context "invalid option" do
      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :section, numeric: { mama: 1..10, in: 5..10 }
        end.new
      end

      it "raises a ::PoroValidator::Exceptions" do
        expect { subject.valid?({ section: 12 }) }.to raise_error(
          ::PoroValidator::InvalidValidator
        )
      end
    end

    context "invalid option value" do
      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :section, numeric: { in: "a" }
        end.new
      end

      it "raises a ::PoroValidator::Exceptions" do
        expect { subject.valid?({ section: 12 }) }.to raise_error(
          ::PoroValidator::InvalidValidator
        )
      end
    end

    # Boundaries not covered above, including integer options beyond the old
    # Fixnum range.
    context "integer option values" do
      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :bounded, numeric: { min: 10, max: 20 }
          validates :inclusive, numeric: 1..10
          validates :exclusive, numeric: 1...10
          validates :cap, numeric: { extremum: 5 }
          validates :negative, numeric: { min: -10, max: 0 }
          validates :large, numeric: { min: 2**64, max: 2**65 }
        end.new
      end

      expect_validator_to_be_valid("values at the lower bounds") do
        let(:entity) do
          OpenStruct.new(bounded: 10, exclusive: 1, negative: -10, large: 2**64)
        end
      end

      expect_validator_to_be_valid("values at the upper bounds") do
        let(:entity) do
          OpenStruct.new(bounded: 20, exclusive: 9, negative: 0, large: 2**65)
        end
      end

      expect_validator_to_be_invalid("values one below the lower bounds") do
        let(:entity) do
          OpenStruct.new(
            bounded: 9,
            inclusive: 0,
            exclusive: 0,
            cap: 4,
            negative: -11,
            large: 2**64 - 1
          )
        end

        let(:expected_errors) do
          {
            "bounded"   => ["does not match the numeric options: {:min=>10}"],
            "inclusive" => ["does not match the numeric options: {:in=>1..10}"],
            "exclusive" => ["does not match the numeric options: {:in=>1...10}"],
            "cap"       => ["does not match the numeric options: {:extremum=>5}"],
            "negative"  => ["does not match the numeric options: {:min=>-10}"],
            "large"     => ["does not match the numeric options: {:min=>#{2**64}}"]
          }
        end
      end

      expect_validator_to_be_invalid("values one above the upper bounds") do
        let(:entity) do
          OpenStruct.new(exclusive: 10, negative: 1, large: 2**65 + 1)
        end

        let(:expected_errors) do
          {
            "exclusive" => ["does not match the numeric options: {:in=>1...10}"],
            "negative"  => ["does not match the numeric options: {:max=>0}"],
            "large"     => ["does not match the numeric options: {:max=>#{2**65}}"]
          }
        end
      end

      expect_validator_to_be_valid("nil values") do
        let(:entity) do
          OpenStruct.new(
            bounded: nil,
            inclusive: nil,
            exclusive: nil,
            cap: nil,
            negative: nil,
            large: nil
          )
        end
      end
    end
  end
end
