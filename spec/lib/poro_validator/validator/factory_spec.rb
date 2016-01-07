require 'spec_helper'

RSpec.describe PoroValidator::Validator::Factory::Validators do
  describe "#new" do
    subject { described_class.set_validator(:foo_attr, validator, {}) }

    context "if it finds the validator class" do
      let(:validator) { :presence }

      it "does not raise an exception" do
        expect { subject }.to_not raise_error
      end
    end

    context "if it does not find the validator class" do
      let(:validator) { :foo }

      it "does raise an exception" do
        expect { subject }.to raise_error(::PoroValidator::ValidatorNotFound)
      end
    end
  end
end
