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
        attr_accessor :entity, :context
      end.new
    end

    before(:each) do
      kontext.entity = entity
      kontext.context = Class.new do
        def name
          "context_name"
        end
      end.new
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
      it "calls the method on the validating instance with the entity" do
        conditions = [ { if: :name } ]

        expect(kontext.context).to receive(:send).with(conditions.first[:if], entity).once
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

      it "also raises for literal nil and false" do
        [nil, false].each do |literal|
          expect do
            described_class.matched?([ { if: literal } ], kontext)
          end.to raise_error(::PoroValidator::InvalidCondition,
                             "Unimplemented condition: #{literal.inspect}")
        end
      end
    end

    context "with the results of Proc conditions" do
      it "reads nil and false as false and anything else as true", :aggregate_failures do
        [true, false, nil, 0, "", [], {}, Object.new].each do |value|
          truthy = !(value.nil? || value == false)

          expect(described_class.matched?([ { if: ->(_context) { value } } ], kontext)).
            to be(truthy), "if returning #{value.inspect}"
          expect(described_class.matched?([ { unless: ->(_context) { value } } ], kontext)).
            to be(!truthy), "unless returning #{value.inspect}"
        end
      end
    end

    context "if a String condition returns nil" do
      it "reads it as false, still evaluating it on the entity" do
        entity.name = nil
        expect(described_class.matched?([ { if: 'name' } ], kontext)).to be(false)

        entity.name = "x"
        expect(described_class.matched?([ { if: 'name' } ], kontext)).to be(true)
      end
    end

    context "if the condition is a lambda that takes no arguments" do
      it "calls it once, without arguments, keeping its self" do
        calls = []
        condition = -> { calls << self; true }

        expect(described_class.matched?([ { if: condition } ], kontext)).to be(true)
        expect(calls.size).to eq(1)
        expect(calls.first).to be(self)
      end

      it "lets an ArgumentError it raises through, calling it once" do
        calls = 0
        error = ArgumentError.new("raised inside the condition")
        condition = -> { calls += 1; raise error }

        expect do
          described_class.matched?([ { if: condition } ], kontext)
        end.to raise_error(ArgumentError) { |raised| expect(raised).to be(error) }
        expect(calls).to eq(1)
      end
    end

    context "if the condition is another Proc or lambda" do
      it "passes it the context, whatever its parameters" do
        received = []
        callables = [
          ->(context) { received << context },
          proc { |context| received << context },
          proc { |context = nil| received << context },
          ->(context = nil) { received << context },
          ->(*args) { received << args },
          proc { |*args| received << args }
        ]

        described_class.matched?([ { if: callables } ], kontext)

        expect(received).to eq([kontext, kontext, kontext, kontext, [kontext], [kontext]])
      end

      it "still raises ArgumentError when it needs two arguments" do
        expect do
          described_class.matched?([ { if: ->(_one, _two) { true } } ], kontext)
        end.to raise_error(ArgumentError, "wrong number of arguments (given 1, expected 2)")
      end
    end

    context "with several conditions" do
      it "evaluates each once, in order, after a nil or false result" do
        calls = []
        conditions = [
          { if: [->(_context) { calls << 1; nil }, -> { calls << 2; true }] },
          { unless: ->(_context) { calls << 3; false } },
          { if: -> { calls << 4; false } }
        ]

        expect(described_class.matched?(conditions, kontext)).to be(false)
        expect(calls).to eq([1, 2, 3, 4])
      end

      it "is satisfied when there are none" do
        expect(described_class.matched?([], kontext)).to be(true)
        expect(described_class.matched?([ { if: [] } ], kontext)).to be(true)
      end
    end
  end
end
