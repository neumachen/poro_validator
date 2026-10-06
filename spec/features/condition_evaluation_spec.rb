require 'spec_helper'

# How a condition is called and how its result is read. A lambda that takes
# no parameters is called without arguments; every other Proc or lambda gets
# the validation Context. A nil or false result counts as false, anything
# else as true. The rule used is `presence` on a missing name, so it adds
# "name is not present" whenever it runs.
RSpec.describe "Condition evaluation", :aggregate_failures, type: :feature do
  let(:named) { Struct.new(:name) }
  let(:ran) { [false, ["name is not present"]] }
  let(:skipped) { [true, []] }

  def validator_for(**declaration)
    Class.new do
      include PoroValidator.validator

      validates :name, **declaration
    end.new
  end

  # The result and error messages of validating a missing name.
  def outcome_of(**declaration)
    validator = validator_for(**declaration)
    [validator.valid?(named.new(nil)), validator.errors.full_messages]
  end

  context "with the result a condition returns" do
    [
      ["true", true, true], ["false", false, false], ["nil", nil, false],
      ["0", 0, true], ["an empty String", "", true], ["an empty Array", [], true],
      ["an empty Hash", {}, true], ["an ordinary object", Object.new, true]
    ].each do |label, value, truthy|
      it "treats #{label} as #{truthy}" do
        expect(outcome_of(presence: { if: ->(_context) { value } })).
          to eq(truthy ? ran : skipped)
        expect(outcome_of(presence: { unless: ->(_context) { value } })).
          to eq(truthy ? skipped : ran)
      end
    end
  end

  context "with a lambda that takes no arguments" do
    it "calls it without arguments and uses its result" do
      expect(outcome_of(presence: { if: -> { true } })).to eq(ran)
      expect(outcome_of(presence: { if: -> { false } })).to eq(skipped)
      expect(outcome_of(presence: { if: -> { nil } })).to eq(skipped)
      expect(outcome_of(presence: { unless: -> { nil } })).to eq(ran)
    end

    it "accepts it for the whole declaration" do
      expect(outcome_of(presence: true, if: -> { false })).to eq(skipped)
      expect(outcome_of(presence: true, if: -> { true })).to eq(ran)
    end

    it "calls it once, with its closure and the self it was written in" do
      calls = []
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: -> { calls << self; true } }
      end

      expect(klass.new.valid?(named.new(nil))).to be(false)
      expect(calls.size).to eq(1)
      expect(calls.first).to be(klass)
    end
  end

  context "with other Procs and lambdas" do
    it "passes them the Context of the current call" do
      received = []
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: ->(context) { received << context; true } }
      end
      validator = klass.new
      entity = named.new(nil)

      validator.valid?(entity)

      context = received.first
      expect(received.size).to eq(1)
      expect(context).to be_a(PoroValidator::Validator::Context)
      expect(context.entity).to be(entity)
      expect(context.context).to be(validator)
      expect(context.errors).to be(validator.errors)
    end

    it "still passes the Context to Procs and to optional or variadic parameters" do
      received = {}
      callables = {
        ordinary_proc:   proc { |context| received[:ordinary_proc] = context; true },
        optional_proc:   proc { |context = nil| received[:optional_proc] = context; true },
        optional_lambda: ->(context = nil) { received[:optional_lambda] = context; true },
        variadic_lambda: ->(*args) { received[:variadic_lambda] = args; true },
        variadic_proc:   proc { |*args| received[:variadic_proc] = args; true }
      }
      validator = validator_for(presence: { if: callables.values })
      entity = named.new(nil)

      expect(validator.valid?(entity)).to be(false)
      contexts = received.values_at(:ordinary_proc, :optional_proc, :optional_lambda) +
                 received.values_at(:variadic_lambda, :variadic_proc).map(&:first)
      expect(received.values_at(:variadic_lambda, :variadic_proc).map(&:size)).to eq([1, 1])
      expect(contexts.size).to eq(5)
      expect(contexts).to all(be(contexts.first))
      expect(contexts.first).to be_a(PoroValidator::Validator::Context)
      expect(contexts.first.entity).to be(entity)
      # A Proc with only an optional parameter has arity 0, like a lambda
      # without parameters, yet still receives the Context.
      expect(callables[:optional_proc].arity).to eq(0)
    end

    it "still runs a rule whose zero-arity Proc returns true" do
      expect(outcome_of(presence: { if: proc { true } })).to eq(ran)
    end
  end

  context "with several conditions" do
    it "evaluates each once, in order, and a nil result still skips the rule" do
      calls = []
      declaration = {
        presence: { if: [->(_context) { calls << :first; nil },
                         ->(_context) { calls << :second; true }] }
      }

      expect(outcome_of(**declaration)).to eq(skipped)
      expect(calls).to eq([:first, :second])
    end

    it "evaluates declaration and rule conditions, of both kinds, once and in order" do
      calls = []
      declaration = {
        presence: { if: [->(_context) { calls << :first; nil }, -> { calls << :second; true }],
                    unless: ->(_context) { calls << :third; false } },
        if: -> { calls << :declaration; true }
      }

      expect(outcome_of(**declaration)).to eq(skipped)
      expect(calls).to eq([:declaration, :first, :second, :third])
    end
  end

  context "with a String condition" do
    it "evaluates it on the entity and reads nil as false" do
      flagged = Struct.new(:name, :strict)
      validator = validator_for(presence: { if: 'strict' })

      expect(validator.valid?(flagged.new(nil, nil))).to be(true)
      expect(validator.errors.full_messages).to eq([])
      expect(validator.valid?(flagged.new(nil, "yes"))).to be(false)
      expect(validator.errors.full_messages).to eq(["name is not present"])
    end
  end

  context "with a Symbol condition" do
    it "calls the method on the validating instance, passing the entity" do
      klass = Class.new do
        include PoroValidator.validator

        def run_rule?(entity)
          true
        end

        validates :name, presence: { if: :run_rule? }
      end

      validator = klass.new
      entity = Struct.new(:name).new(nil)  # nil name -> presence fails
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on("name")).to eq(["is not present"])
    end

    it "skips the rule when Symbol returns false (nil name but no errors)" do
      klass = Class.new do
        include PoroValidator.validator

        def skip_rule?(entity)
          false
        end

        validates :name, presence: { if: :skip_rule? }
      end

      validator = klass.new
      entity = Struct.new(:name).new(nil)  # nil name but rule skipped
      expect(validator.valid?(entity)).to be(true)
      expect(validator.errors).to be_empty
    end

    it "does not fall back to entity-only methods" do
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: :entity_only_method }
      end

      entity = Struct.new(:name) do
        def entity_only_method(entity)
          true
        end
      end.new(nil)

      # Method doesn't exist on validator -> NoMethodError
      expect { klass.new.valid?(entity) }.to raise_error(NoMethodError)
    end
  end

  context "when a condition raises" do
    it "lets an ArgumentError the condition raises through, calling it once" do
      calls = []
      error = ArgumentError.new("raised by the condition")
      {
        "one-argument lambda" => ->(_context) { calls << :one; raise error },
        "zero-argument lambda" => -> { calls << :zero; raise error }
      }.each do |label, condition|
        validator = validator_for(presence: { if: condition })

        expect { validator.valid?(named.new(nil)) }.
          to raise_error(ArgumentError) { |raised| expect(raised).to be(error), label }
      end
      expect(calls).to eq([:one, :zero])
    end

    it "lets another exception through and stops there" do
      calls = []
      error = KeyError.new("raised by the condition")
      validator = validator_for(presence: {
        if: [->(_context) { calls << :first; raise error }, ->(_context) { calls << :second; true }]
      })

      expect { validator.valid?(named.new(nil)) }.
        to raise_error(KeyError) { |raised| expect(raised).to be(error) }
      expect(calls).to eq([:first])
    end

    it "still raises for a lambda that needs two arguments and for literal conditions" do
      expect { outcome_of(presence: { if: ->(_one, _two) { true } }) }.
        to raise_error(ArgumentError, "wrong number of arguments (given 1, expected 2)")
      [true, false, nil].each do |literal|
        expect { outcome_of(presence: { if: literal }) }.to raise_error(
          PoroValidator::InvalidCondition, "Unimplemented condition: #{literal.inspect}"
        )
      end
    end
  end
end
