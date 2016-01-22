require 'spec_helper'

class AddressValidator
  include PoroValidator.validator

  validates :line1, presence: true
  validates :line2, presence: true
end

class FirstNameValidator
  include PoroValidator.validator

  validates :first_name, presence: true
end

RSpec.describe PoroValidator::Validators::WithValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :first_name, with: FirstNameValidator
        validates :last_name, presence: true, if: proc { true }
        validates :dob, presence: true, if: proc { false }
        validates :address, with: AddressValidator
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          first_name: nil,
          last_name: nil,
          dob: nil,
          address: OpenStruct.new(
            line1: nil,
            line2: nil
          )
        )
      end

      let(:expected_errors) do
        {
          "first_name" => ["is not present"],
          "last_name" => ["is not present"],
          "{:address=>:line1}" => ["is not present"],
          "{:address=>:line2}" => ["is not present"]
        }
      end

      skip_attr_unmet_condition do
        let(:attr) { :dob }
      end
    end

    context "entity is a hash object" do
      expect_validator_to_be_invalid do
        let(:entity) do
          {}
        end

        let(:expected_errors) do
          {
            "first_name" => ["is not present"],
            "last_name" => ["is not present"],
            "{:address=>:line1}" => ["is not present"],
            "{:address=>:line2}" => ["is not present"]
          }
        end

        skip_attr_unmet_condition do
          let(:attr) { :dob }
        end
      end

    end

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          first_name: "manbearpig",
          last_name: "gore",
          dob: "01/01/1977",
          address: OpenStruct.new(
            line1: "foo",
            line2: "boo"
          )
        )
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        {
          first_name: "manbearpig",
          last_name: "gore",
          dob: "01/01/1977",
          address: {
            line1: "foo",
            line2: "boo"
          }
        }
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        {
          "first_name" => "manbearpig",
          "last_name" => "gore",
          "dob" => "01/01/1977",
          "address" => {
            "line1" => "foo",
            "line2" => "boo"
          }
        }
      end
    end

    context "non class is passed for with:" do
      let(:entity) do
        OpenStruct.new
      end

      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :first_name, presence: true
          validates :last_name, presence: true, if: proc { true }
          validates :dob, presence: true, if: proc { false }
          validates :address, with: :presence
        end.new
      end

      it "raises an error" do
        expect { subject.valid?(entity) }.to raise_error(
          ::PoroValidator::InvalidValidator,
          "Requires a class object for this validator."
        )
      end
    end
  end
end
