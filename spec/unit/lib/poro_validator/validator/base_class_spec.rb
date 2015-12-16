require 'spec_helper'

RSpec.describe PoroValidator::Validator::BaseClass do
  subject { described_class.new }

  describe "<<" do
    it "add/set validations" do
      validation = [:foo, :faa]
      subject << validation
      expect(subject.validations).to eq([validation])
    end
  end

  describe "#run_validations" do
    let(:kontext) do
      Class.new do
        attr_accessor :entity
      end.new
    end

    let(:klass) do
      Class.new do
        def __validate__(kotenxt)
          true
        end
      end
    end

    context "if the conditions are matched" do
      it "runs each validation" do
        allow(PoroValidator::Validator::Conditions).to receive(:matched?).and_return(true)

        validator1 = { validator: klass.new, conditions: [nil] }
        validator2 = { validator: klass.new, conditions: [nil] }

        subject << validator1
        subject << validator2

        expect(validator1[:validator]).to receive(:__validate__).
          with(kontext).once
        expect(validator2[:validator]).to receive(:__validate__).
          with(kontext).once

        subject.run_validations(kontext)
      end
    end

    context "if the conditions are not matched" do
      it "does not runs the validation" do
        allow(PoroValidator::Validator::Conditions).to receive(:matched?).and_return(false)

        validator = { validator: klass.new, conditions: [nil] }

        subject << validator

        expect(validator[:validator]).to_not receive(:__validate__)

        subject.run_validations(kontext)
      end

    end
  end
end
