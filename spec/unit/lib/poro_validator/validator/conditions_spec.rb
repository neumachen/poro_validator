require 'spec_helper'

RSpec.describe PoroValidator::Validator::Conditions do
  describe ".matched?" do
    let(:entity) do
      Class.new do
        attr_accessor :name
      end.new
    end

    let(:kontext) do
      Class.new do
        attr_accessor :entity
      end.new
    end

    before(:each) do
      kontext.entity = entity
    end

    context "if the conditions are matched" do
      it "returns true" do
        conditions = [ { if: proc { true } }, { if: proc { true } } ]

        expect(described_class.matched?(conditions, kontext)).to be_truthy
      end

      context "if :unless conditions are met" do
        it "returns true" do
          conditions = [ { if: proc { true } }, { unless: proc { false } } ]

          expect(described_class.matched?(conditions, kontext)).to be_truthy
        end
      end
    end

    context "if the conditions are not matched" do
      it "returns false" do
        conditions = [ { if: proc { true } }, { if: proc { false } } ]

        expect(described_class.matched?(conditions, kontext)).to be_falsey
      end

      context "if :unless conditions are not met" do
        it "returns true" do
          conditions = [ { if: proc { true } }, { unless: proc { true } } ]

          expect(described_class.matched?(conditions, kontext)).to be_falsey
        end
      end
    end

    context "if the conditions are passed in an array" do
      it "runs each condition" do
        condition1 = lambda { true }
        condition2 = lambda { true }
        conditions = [ { if: [condition1, condition2] } ]

        expect(condition1).to receive(:call).once
        expect(condition2).to receive(:call).once
        described_class.matched?(conditions, kontext)
      end
    end

    context "if the condition type is unknown" do
      it "raises an exception ::PoroValidator::InvalidCondition" do
        conditions = [ { hello: true } ]

        expect do
          described_class.matched?(conditions, kontext)
        end.to raise_error(::PoroValidator::InvalidCondition)
      end
    end

    context "if the condition is a String" do
      it "evaluates the string based on the context's entity" do
        conditions = [ { if: 'name.nil?' } ]

        expect(entity).to receive(:instance_eval).with(conditions.first[:if]).once
        described_class.matched?(conditions, kontext)
      end
    end

    context "if the condition is a Symbol" do
      it "calls the lambda for that condition type" do
        conditions = [ { if: :name } ]

        expect(kontext).to receive(:send).with(conditions.first[:if], entity).once
        described_class.matched?(conditions, kontext)
      end
    end

    context "if the condition is a Proc" do
      it "calls the lambda/proc for that condition type" do
        conditions = [ { if: proc { true } } ]

        expect(conditions.first[:if]).to receive(:call).once
        described_class.matched?(conditions, kontext)
      end
    end

    context "if the condition is neither of the cases" do
      it "raises an exception ::PoroValidator::ValidatorException" do
        conditions = [ { if: true } ]

        expect do
          described_class.matched?(conditions, kontext)
        end.to raise_error(::PoroValidator::InvalidCondition)
      end
    end
  end
end
