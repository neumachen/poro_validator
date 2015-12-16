require 'spec_helper'

RSpec.describe PoroValidator::Validator::Validation do
  describe ".build" do
    let(:options) { {} }
    # we are defaulting to presence validator so that it does not error out
    # if we pass in a random non existent validator for this tests
    let(:validator) { :presence }

    subject { described_class.build(:foo_attr, validator, options) }

    it "returns a Validators object" do
      expect(subject).to be_a(PoroValidator::Validators::BaseClass)
    end

    it "sets the validator to the Validator Class" do
      expect(subject.class.name).to eq('PoroValidator::Validators::PresenceValidator')
    end


    context "if options is TrueClass" do
      let(:options) { true }

      it "sets the options to a hash" do
        expect(subject.options).to eq({})
      end
    end

    context "if options is Range" do
      let(:options) { 1..3 }

      it "sets options to a hash with an in: key with an range value" do
        expect(subject.options).to eq({ in: 1..3 })
      end
    end

    context "if options is Array" do
      let(:options) { ['foo', 'faa'] }

      it "sets options to a hash with an in: key with an array value" do
        expect(subject.options).to eq({ in: ['foo', 'faa'] })
      end
    end

    context "if options doe not match any case" do
      let(:options) { 55 }

      it "converts it to a hash with a with: key" do
        expect(subject.options).to eq({ with: 55 })
      end
    end
  end

  describe "#attr_name" do
    subject { described_class.new(:foo_attr, :foo_validator, {}) }

    it "returns the attribute name" do
      expect(subject.attr_name).to eq(:foo_attr)
    end
  end

  describe "#validator" do
    subject { described_class.new(:foo_attr, :foo_validator, {}) }

    it "returns the validator" do
      expect(subject.validator).to eq(:foo_validator)
    end
  end
end
