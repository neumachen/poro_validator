require 'spec_helper'

RSpec.describe PoroValidator::Validators::PresenceValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    let(:attribute)       { :name }
    let(:attribute_value) { value }
    let(:expected_error)  { nil }
    let(:validation)      { { presence: true } }
    let(:condition)       { true }
    let(:conditions)      { { if: proc { condition } } }

    context "if the condition is met" do
      let(:condition) { true }

      context "and the value is not valid" do
        let(:value)          { nil }
        let(:expected_error) { ["is not present"] }

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
  end
end
