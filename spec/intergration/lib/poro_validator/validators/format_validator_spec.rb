require 'spec_helper'

RSpec.describe PoroValidator::Validators::FormatValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :first_name, format: /[a-z]/
        validates :last_name, format: /[a-z]/, if: proc { true }
        validates :dob, format: /[0-9]/, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          first_name: "0000",
          last_name: "1111",
          dob: "aaaa"
        )
      end

      let(:expected_errors) do
        {
          "first_name" => ["does not match the pattern: /[a-z]/"],
          "last_name" => ["does not match the pattern: /[a-z]/"]
        }
      end

      skip_attr_unmet_condition do
        let(:attr) { :dob }
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          first_name: "manbearpig",
          last_name: "gore",
          dob: "01/01/1977"
        )
      end
    end
  end
end
