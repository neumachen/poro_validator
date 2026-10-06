require 'spec_helper'

# Symbol conditions dispatch to the validating instance (not Context, not entity).
# The method receives exactly one argument: the entity being validated.
RSpec.describe "Symbol conditions", :aggregate_failures, type: :feature do
  let(:named) { Struct.new(:name) }

  context "receiver and argument" do
    it "calls a public validator method with the entity" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :called_with

        def initialize
          @called_with = nil
        end

        def check_entity(entity)
          @called_with = entity
          true
        end

        validates :name, presence: { if: :check_entity }
      end

      entity = named.new(nil)  # nil name -> presence fails -> valid? false
      validator = klass.new
      expect(validator.valid?(entity)).to be(false)
      expect(validator.called_with).to be(entity)
    end

    it "calls a private validator method via send" do
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: :allow? }

        private

        def allow?(entity)
          true
        end
      end

      expect(klass.new.valid?(named.new(nil))).to be(false)
    end

    it "calls a protected validator method via send" do
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: :allowed? }

        protected

        def allowed?(entity)
          true
        end
      end

      expect(klass.new.valid?(named.new(nil))).to be(false)
    end

    it "does not fall back to entity-only methods" do
      # Method exists only on entity, not on validator -> NoMethodError on
      # the validator, inspecting the actual receiver/name rather than
      # accepting any unrelated NoMethodError.
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: :entity_only_method }
      end

      entity = Struct.new(:name) do
        def entity_only_method(entity)
          true
        end
      end.new(nil)

      validator = klass.new
      expect { validator.valid?(entity) }.to raise_error(NoMethodError) { |e|
        expect(e.name).to eq(:entity_only_method)
        expect(e.receiver).to be(validator)
      }
    end

    it "does not fall back to Context-only methods" do
      # :entity exists on PoroValidator::Validator::Context, not on the
      # validator instance. A genuine Symbol condition naming it must raise
      # NoMethodError on the validator, not succeed via a Context fallback.
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: :entity }
      end

      validator = klass.new
      expect { validator.valid?(named.new(nil)) }.to raise_error(NoMethodError) { |e|
        expect(e.name).to eq(:entity)
        expect(e.receiver).to be(validator)
      }
    end
  end

  context "nil rule input discriminates run from skip" do
    it "runs the rule when Symbol returns true (nil name fails presence)" do
      klass = Class.new do
        include PoroValidator.validator

        def run?(entity)
          true
        end

        validates :name, presence: { if: :run? }
      end

      validator = klass.new
      entity = named.new(nil)  # nil name -> presence fails
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on("name")).to eq(["is not present"])
    end

    it "skips the rule when Symbol returns false (nil name but no errors)" do
      klass = Class.new do
        include PoroValidator.validator

        def skip?(entity)
          false
        end

        validates :name, presence: { if: :skip? }
      end

      validator = klass.new
      entity = named.new(nil)  # nil name but rule skipped
      expect(validator.valid?(entity)).to be(true)
      expect(validator.errors).to be_empty
    end
  end

  context "same-name validator vs entity method" do
    it "uses the validator method, not the entity method, to skip the rule" do
      klass = Class.new do
        include PoroValidator.validator

        def enabled?(entity)
          false  # validator method returns false -> skip rule
        end

        validates :name, presence: { if: :enabled? }
      end

      entity = Struct.new(:name) do
        def enabled?(entity)
          true  # entity method returns true, but must NOT be consulted
        end
      end.new(nil)  # nil name: if the rule ran, presence would fail

      validator = klass.new
      # Validator#enabled? returns false -> rule skipped -> valid despite nil name.
      # If dispatch fell back to entity.enabled? (true), the rule would run and
      # fail presence, making valid? false instead of the expected true.
      expect(validator.valid?(entity)).to be(true)
      expect(validator.errors).to be_empty
    end

    it "uses the validator method, not the entity method, to run the rule" do
      klass = Class.new do
        include PoroValidator.validator

        def enabled?(entity)
          true  # validator method returns true -> run rule
        end

        validates :name, presence: { if: :enabled? }
      end

      entity = Struct.new(:name) do
        def enabled?(entity)
          false  # entity method returns false, but must NOT be consulted
        end
      end.new(nil)  # nil name: rule runs and fails presence

      validator = klass.new
      # Validator#enabled? returns true -> rule runs -> presence fails (nil name).
      # If dispatch fell back to entity.enabled? (false), the rule would be
      # skipped, making valid? true instead of the expected false.
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on("name")).to eq(["is not present"])
    end
  end

  context "truthiness" do
    it "treats nil as false (skips rule)" do
      klass = Class.new do
        include PoroValidator.validator

        def check(entity)
          nil
        end

        validates :name, presence: { if: :check }
      end

      expect(klass.new.valid?(named.new(nil))).to be(true)  # skipped
    end

    it "treats false as false (skips rule)" do
      klass = Class.new do
        include PoroValidator.validator

        def check(entity)
          false
        end

        validates :name, presence: { if: :check }
      end

      expect(klass.new.valid?(named.new(nil))).to be(true)  # skipped
    end

    it "treats truthy values (0, \"\", []) as true (runs rule)" do
      [0, "", [], {}, "yes"].each do |truthy|
        klass = Class.new do
          include PoroValidator.validator

          define_method(:check) { |entity| truthy }

          validates :name, presence: { if: :check }
        end

        expect(klass.new.valid?(named.new(nil))).to be(false), "expected #{truthy.inspect} to run rule"
      end
    end

    it "reverses truthiness for :unless when the condition returns true (skips)" do
      klass = Class.new do
        include PoroValidator.validator

        def check(entity)
          true  # :unless true means skip
        end

        validates :name, presence: { unless: :check }
      end

      expect(klass.new.valid?(named.new(nil))).to be(true)  # skipped by :unless
    end

    it "reverses truthiness for :unless when the condition returns nil (runs)" do
      klass = Class.new do
        include PoroValidator.validator

        def check(entity)
          nil  # nil -> false -> :unless means do NOT skip -> rule runs
        end

        validates :name, presence: { unless: :check }
      end

      expect(klass.new.valid?(named.new(nil))).to be(false)  # rule runs, presence fails
    end

    it "reverses truthiness for :unless when the condition returns a non-boolean truthy value (skips)" do
      klass = Class.new do
        include PoroValidator.validator

        def check(entity)
          0  # truthy, non-boolean -> :unless means skip
        end

        validates :name, presence: { unless: :check }
      end

      expect(klass.new.valid?(named.new(nil))).to be(true)  # skipped by :unless
    end
  end

  context "Hash input" do
    it "dispatches to the validator with the normalized Hash entity" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :received_entity

        def entity_check(entity)
          @received_entity = entity
          true
        end

        validates :name, presence: { if: :entity_check }
      end

      validator = klass.new
      validator.valid?({ "name" => nil })
      # Hash input is normalized to symbol keys before dispatch.
      expect(validator.received_entity).to eq({ name: nil })
    end
  end

  context "arrays and mixed types with eager ordering" do
    it "evaluates all conditions in order after a failure, including String" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :calls

        def initialize
          @calls = []
        end

        def first?(entity)
          @calls << :symbol_first
          false  # fails, but evaluation is eager and continues
        end

        def second?(entity)
          @calls << :symbol_second
          true
        end

        validates :name, presence: {
          if: [:first?, :second?, "mark_string_evaluated"]
        }
      end

      validator = klass.new
      entity = named.new(nil)
      entity.define_singleton_method(:mark_string_evaluated) do
        validator.calls << :string
        true
      end

      expect(validator.valid?(entity)).to be(true)  # first? fails -> rule skipped
      # The String condition was actually evaluated (not skipped), in order,
      # after the earlier false Symbol result.
      expect(validator.calls).to eq([:symbol_first, :symbol_second, :string])
    end

    it "evaluates Symbol, Proc, and String in order with mixed results" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :calls

        def initialize
          @calls = []
        end

        def sym_cond(entity)
          @calls << :symbol
          true
        end

        validates :name, presence: {
          if: [:sym_cond, ->(ctx) { ctx.context.calls << :proc; false }, "mark_string_evaluated"]
        }
      end

      entity = named.new("present")
      validator = klass.new
      entity.define_singleton_method(:mark_string_evaluated) do
        validator.calls << :string
        true
      end

      expect(validator.valid?(entity)).to be(true)  # proc returns false -> rule skipped
      expect(validator.calls).to eq([:symbol, :proc, :string])
    end
  end

  context "declaration-level conditions with sibling scope" do
    it "applies declaration condition to all rules in the declaration" do
      klass = Class.new do
        include PoroValidator.validator

        def decl_check(entity)
          false  # skip all rules in this declaration
        end

        validates :name, presence: true, length: { min: 5 }, if: :decl_check
      end

      validator = klass.new
      entity = named.new("ab")  # would fail length if rule ran
      expect(validator.valid?(entity)).to be(true)  # all rules skipped
      expect(validator.errors).to be_empty
    end

    it "rule-local conditions only affect their own rule" do
      klass = Class.new do
        include PoroValidator.validator

        def skip_length?(entity)
          false  # skip length rule
        end

        validates :name, presence: true, length: { min: 5, if: :skip_length? }
      end

      validator = klass.new
      entity = named.new(nil)  # presence fails (nil name)
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on("name")).to eq(["is not present"])
    end
  end

  context "inheritance and overrides" do
    it "uses inherited method from parent class" do
      parent = Class.new do
        def validate?(entity)
          true
        end
      end

      child = Class.new(parent) do
        include PoroValidator.validator

        validates :name, presence: { if: :validate? }
      end

      expect(child.new.valid?(named.new(nil))).to be(false)  # rule runs, presence fails
    end

    it "uses subclass override" do
      parent = Class.new do
        include PoroValidator.validator

        def check?(entity)
          true  # parent runs rule
        end

        validates :name, presence: { if: :check? }
      end

      child = Class.new(parent) do
        def check?(entity)
          false  # child skips rule
        end
      end

      expect(parent.new.valid?(named.new(nil))).to be(false)  # parent runs
      expect(child.new.valid?(named.new(nil))).to be(true)    # child skips
    end
  end

  context "independent instances and repeated validation" do
    it "two independent validator instances do not share state" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :entities_checked

        def initialize
          @entities_checked = []
        end

        def track(entity)
          @entities_checked << entity
          true
        end

        validates :name, presence: { if: :track }
      end

      v1 = klass.new
      v2 = klass.new
      entity1 = named.new("a")
      entity2 = named.new("b")

      v1.valid?(entity1)
      v2.valid?(entity2)

      expect(v1.entities_checked).to eq([entity1])
      expect(v2.entities_checked).to eq([entity2])
    end

    it "repeated validation with different entities uses the fresh entity each time" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :entities_checked

        def initialize
          @entities_checked = []
        end

        def track(entity)
          @entities_checked << entity
          true
        end

        validates :name, presence: { if: :track }
      end

      validator = klass.new
      entity1 = named.new("a")
      entity2 = named.new("b")

      validator.valid?(entity1)
      validator.valid?(entity2)

      expect(validator.entities_checked).to eq([entity1, entity2])
    end
  end

  context "missing method and wrong arity" do
    it "raises NoMethodError for a missing validator method" do
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { if: :nonexistent_method }
      end

      validator = klass.new
      expect { validator.valid?(named.new(nil)) }.to raise_error(NoMethodError) { |e|
        expect(e.name).to eq(:nonexistent_method)
        expect(e.receiver).to be(validator)
      }
    end

    it "raises ArgumentError for wrong number of arguments" do
      klass = Class.new do
        include PoroValidator.validator

        def check?(a, b)
          true
        end

        validates :name, presence: { if: :check? }
      end

      expect { klass.new.valid?(named.new(nil)) }.to raise_error(ArgumentError)
    end
  end

  context "exception propagation" do
    it "propagates the exact exception object raised by the condition method" do
      error = StandardError.new("condition boom")
      klass = Class.new do
        include PoroValidator.validator

        define_method(:exploding) { |entity| raise error }

        validates :name, presence: { if: :exploding }
      end

      expect { klass.new.valid?(named.new(nil)) }.to raise_error(StandardError) { |raised|
        expect(raised).to be(error)  # exact same object, not merely same class/message
      }
    end

    it "method is called exactly once (no retry)" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :call_count

        def initialize
          @call_count = 0
        end

        def exploding(entity)
          @call_count += 1
          raise StandardError, "stop"
        end

        validates :name, presence: { if: :exploding }
      end

      validator = klass.new
      expect { validator.valid?(named.new(nil)) }.to raise_error(StandardError, "stop")
      expect(validator.call_count).to eq(1)  # called exactly once
    end

    it "exception stops evaluation of subsequent conditions" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :calls

        def initialize
          @calls = []
        end

        def first(entity)
          @calls << :first
          raise StandardError, "stop"
        end

        def second(entity)
          @calls << :second
          true
        end

        validates :name, presence: { if: [:first, :second] }
      end

      validator = klass.new
      expect { validator.valid?(named.new(nil)) }.to raise_error(StandardError, "stop")
      expect(validator.calls).to eq([:first])  # second never called
    end
  end
end
