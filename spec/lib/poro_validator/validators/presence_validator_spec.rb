require 'spec_helper'

RSpec.describe PoroValidator::Validators::PresenceValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :first_name, presence: true
        validates :last_name, presence: true, if: proc { true }
        validates :nickname, presence: { allow_blank: true }
        validates :dob, presence: true, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          first_name: nil,
          last_name: nil,
          nickname: nil,
          dob: nil
        )
      end

      let(:expected_errors) do
        {
          "first_name" => ["is not present"],
          "last_name"  => ["is not present"],
          "nickname"   => ["is not present"]
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
          nickname: "",
          dob: "01/01/1977"
        )
      end
    end
  end
end
