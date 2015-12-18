require 'spec_helper'

RSpec.describe PoroValidator::Validators::FormatValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    let(:attribute)       { :name }
    let(:attribute_value) { value }
    let(:expected_error)  { nil }
    let(:validation)      { { format: /[a-z]/ } }
    let(:condition)       { true }
    let(:conditions)      { { if: proc { condition } } }

    # test_validator(
    #   validator, entity
    # ).expect_to_pass(condition: true, value: values[:valid])
    #
    # test_validator(
    #   validator, entity
    # ).expect_to_pass(condition: false, value: values[:valid])

    context "if the condition is met" do
      let(:condition) { true }

      context "and the value is not valid" do
        let(:value)          { "0000" }
        let(:expected_error) { ["does not match the pattern: /[a-z]/"] }

        expects_to_fail_validation
      end

      context "and the value is valid" do
        let(:value) { "aaaa" }

        expects_to_pass_validation
      end
    end

    context "if the condition is not met" do
      let(:condition) { false }
      let(:value)     { "aaaa" }

      expects_to_pass_validation
    end

    context "if the attribute value is not passed or is nil" do
      let(:value) { nil }

      expects_to_pass_validation
    end
  end
end
