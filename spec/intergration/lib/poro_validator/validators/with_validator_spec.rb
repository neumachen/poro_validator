require 'spec_helper'

class AddressValidator
  include PoroValidator.validator

  validates :line1, presence: true
  validates :line2, presence: true
end

RSpec.describe PoroValidator::Validators::WithValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    let(:attribute)       { :address }
    let(:attribute_value) { value }
    let(:expected_error)  { nil }
    let(:validation)      { { with: AddressValidator } }
    let(:condition)       { true }
    let(:conditions)      { { if: proc { condition } } }

    context "if the condition is met" do
      let(:condition) { true }

      context "and the value is not valid" do
        let(:value)          { OpenStruct.new(line1: nil, line2: nil) }
        let(:expected_error) do
          [
            ["line1", ["is not present"]],
            ["line2", ["is not present"]]
          ]
        end

        expects_to_fail_validation
      end

      context "and the value is valid" do
        let(:value) { OpenStruct.new(line1: "foo", line2: "boo") }

        expects_to_pass_validation
      end
    end

    context "if the condition is not met" do
      let(:condition) { false }
      let(:value)     { OpenStruct.new(line1: "foo", line2: "boo") }

      expects_to_pass_validation
    end

    context "if a non class is passed for with:" do
      let(:value)      { OpenStruct.new(line1: "foo", line2: "boo") }
      let(:validation) { { with: :presence } }

      expects_to_raise_error
    end
  end
end
