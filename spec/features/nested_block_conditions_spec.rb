require 'spec_helper'

# Outer :if/:unless on a `validates :attr, if: ..., do ... end` block
# propagate to every leaf validation contained in that block, at every
# nesting depth, combined with each leaf's own declaration/rule-local
# conditions. All groups use the SAME execution context: the root entity
# passed to the top-level #valid?, and the actual validating instance.
RSpec.describe "Nested block conditions", :aggregate_failures, type: :feature do
  let(:customer_class) { Struct.new(:name, :address) }
  let(:address_class)  { Struct.new(:line1, :country) }
  let(:country_class)  { Struct.new(:code) }

  context "outer :if/:unless controls every nested leaf" do
    it "skips every nested leaf when outer :if is false" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { false } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      validator = klass.new
      expect(validator.valid?(entity)).to be(true)
      expect(validator.errors).to be_empty
    end

    it "skips every nested leaf when outer :if is nil" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { nil } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      expect(klass.new.valid?(entity)).to be(true)
    end

    it "runs every nested leaf when outer :if is true, producing nested errors" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { true } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      validator = klass.new
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on([:address, :line1])).to eq(["is not present"])
    end

    it "leaves a sibling rule outside the block active regardless of the outer condition" do
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: true

        validates :address, if: ->(_c) { false } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new(nil, address_class.new(nil, nil))
      validator = klass.new
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on(:name)).to eq(["is not present"])
      expect(validator.errors.on([:address, :line1])).to be_nil
    end

    it "reverses with :unless: true skips, false runs" do
      skip_klass = Class.new do
        include PoroValidator.validator

        validates :address, unless: ->(_c) { true } do
          validates :line1, presence: true
        end
      end
      run_klass = Class.new do
        include PoroValidator.validator

        validates :address, unless: ->(_c) { false } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      expect(skip_klass.new.valid?(entity)).to be(true)
      expect(run_klass.new.valid?(entity)).to be(false)
    end

    it "treats :unless nil as falsy (runs) and a non-boolean truthy value as truthy (skips)" do
      nil_klass = Class.new do
        include PoroValidator.validator

        validates :address, unless: ->(_c) { nil } do
          validates :line1, presence: true
        end
      end
      truthy_klass = Class.new do
        include PoroValidator.validator

        validates :address, unless: ->(_c) { 0 } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      expect(nil_klass.new.valid?(entity)).to be(false)     # falsy -> does not skip -> runs
      expect(truthy_klass.new.valid?(entity)).to be(true)   # truthy -> skips
    end
  end

  context "combination order across nesting levels" do
    it "evaluates outer, inner, declaration and rule-local groups in order, eagerly, including String" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :trace

        def initialize
          @trace = []
        end

        def outer_cond(entity)
          @trace << :outer
          true
        end

        def inner_cond(entity)
          @trace << :inner
          true
        end

        def decl_cond(entity)
          @trace << :declaration
          false  # eager: evaluation continues past this false result
        end

        def rule_cond(entity)
          @trace << :rule_local
          true
        end

        validates :address, if: :outer_cond do
          validates :country, if: :inner_cond do
            validates :code, presence: { if: :rule_cond }, if: [:decl_cond, "mark_string"]
          end
        end
      end

      validator = klass.new
      entity = customer_class.new("x", address_class.new(nil, country_class.new(nil)))
      # String conditions evaluate via context.entity.instance_eval, i.e.
      # against the ROOT entity -- not the nested :country object -- even
      # though this condition is declared deep inside the nested block.
      entity.define_singleton_method(:mark_string) do
        validator.trace << :string
        false
      end

      # decl_cond and the String condition both fail -> rule skipped overall,
      # but every group is still evaluated in order (eager, no short-circuit).
      expect(validator.valid?(entity)).to be(true)
      expect(validator.trace).to eq([:outer, :inner, :declaration, :string, :rule_local])
    end
  end

  context "sibling and nested-block isolation" do
    it "a passing outer condition does not override a false local condition" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { true } do
          validates :line1, presence: true, if: ->(_c) { false }
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      expect(klass.new.valid?(entity)).to be(true)  # local condition still skips the rule
    end

    it "two separate nested blocks do not leak conditions into each other" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { false } do
          validates :line1, presence: true
        end

        validates :name do
          validates :first, presence: true
        end
      end

      entity = Struct.new(:address, :name).new(
        address_class.new(nil, nil),
        Struct.new(:first).new(nil)
      )
      validator = klass.new
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on([:address, :line1])).to be_nil             # skipped by its own outer condition
      expect(validator.errors.on([:name, :first])).to eq(["is not present"]) # unconditioned, runs
    end
  end

  context "receiver and argument for nested block conditions" do
    it "a private Symbol method on the parent validator receives the root entity, not a nested value" do
      klass = Class.new do
        include PoroValidator.validator

        attr_reader :received

        def initialize
          @received = nil
        end

        validates :address, if: :root_check do
          validates :line1, presence: true
        end

        private

        def root_check(entity)
          @received = entity
          true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      validator = klass.new
      validator.valid?(entity)
      expect(validator.received).to be(entity)  # the root entity, not entity.address
    end

    it "with a String-keyed Hash root entity, the Context/validator/root-entity arguments are correct" do
      # Procs/lambdas close over lexical self at their definition site, not
      # the instance that calls them, so results are captured in local
      # variables (as elsewhere in this suite), not instance variables set
      # from inside a Class.new block.
      received_context = nil
      received_validator = nil
      received_entity = nil

      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(context) {
          received_context = context
          received_entity = context.entity
          received_validator = context.context
          true
        } do
          validates :line1, presence: true
        end
      end

      validator = klass.new
      validator.valid?({ "address" => { "line1" => nil } })
      expect(received_entity).to eq({ address: { line1: nil } })  # normalized symbol keys
      expect(received_validator).to be(validator)
      expect(received_context).to be_a(PoroValidator::Validator::Context)
    end
  end

  context "skipped leaves do not dereference missing nested data" do
    it "does not call the accessor for a nil nested object when the outer condition skips it" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { false } do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", nil)  # entity.address is nil
      # If the leaf ran, entity.address.line1 would raise NoMethodError on nil.
      expect(klass.new.valid?(entity)).to be(true)
    end

    it "an outer false condition does not suppress a local condition's exception, which still stops later conditions" do
      # Eager evaluation means a false outer result does not short-circuit
      # the leaf's own local condition group -- only an exception does. The
      # outer group is recorded before the local group raises, proving the
      # local group was still reached despite the outer result already
      # being false.
      error = StandardError.new("boom")
      calls = []
      klass = Class.new do
        include PoroValidator.validator

        define_method(:exploding) { |entity| calls << :local; raise error }
        define_method(:never_reached) { |entity| calls << :never_reached; true }

        validates :address, if: ->(_c) { calls << :outer; false } do
          validates :line1, presence: true, if: [:exploding, :never_reached]
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      validator = klass.new
      expect { validator.valid?(entity) }.to raise_error(StandardError) { |e| expect(e).to be(error) }
      # :outer ran (and was false), then :local ran and raised; :never_reached
      # never ran (no retry, later conditions do not execute after the raise).
      expect(calls).to eq([:outer, :local])
    end
  end

  context "frozen/reused options, repeated calls, instances, inheritance, empty blocks" do
    it "does not mutate the caller's condition Hash" do
      shared_conditions = { if: ->(_c) { true } }.freeze

      klass = Class.new do
        include PoroValidator.validator

        validates :address, **shared_conditions do
          validates :line1, presence: true
        end
      end

      expect { klass.new.valid?(customer_class.new("x", address_class.new(nil, nil))) }.
        not_to raise_error
      expect(shared_conditions.frozen?).to be(true)
      expect(shared_conditions.keys).to eq([:if])
    end

    it "repeated validation calls do not accumulate duplicate conditions or errors" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { true } do
          validates :line1, presence: true
        end
      end

      validator = klass.new
      entity = customer_class.new("x", address_class.new(nil, nil))
      validator.valid?(entity)
      first_count = validator.errors.count
      validator.valid?(entity)
      second_count = validator.errors.count
      expect(second_count).to eq(first_count)
      expect(klass.validations.validations.length).to eq(1)  # not re-added
    end

    it "two validator instances remain independent" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { true } do
          validates :line1, presence: true
        end
      end

      v1 = klass.new
      v2 = klass.new
      v1.valid?(customer_class.new("x", address_class.new(nil, nil)))
      v2.valid?(customer_class.new("x", address_class.new("present", nil)))

      expect(v1.errors.on([:address, :line1])).to eq(["is not present"])
      expect(v2.errors.on([:address, :line1])).to be_nil
    end

    it "inheritance carries the propagated nested block conditions without duplication" do
      parent = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { false } do
          validates :line1, presence: true
        end
      end

      child = Class.new(parent) do
        validates :name, presence: true
      end

      entity = customer_class.new(nil, address_class.new(nil, nil))
      validator = child.new
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on(:name)).to eq(["is not present"])
      expect(validator.errors.on([:address, :line1])).to be_nil  # still skipped, not duplicated
      expect(child.validations.validations.length).to eq(2)
    end

    it "an empty block produces no leaves and never evaluates the outer condition" do
      called = false
      klass = Class.new do
        include PoroValidator.validator
      end
      klass.validates(:address, if: ->(_c) { called = true }) {}

      expect(klass.validations.validations).to eq([])
      expect(klass.new.valid?(customer_class.new("x", nil))).to be(true)
      expect(called).to be(false)
    end
  end

  context "per-leaf evaluation across two leaves and two nesting levels" do
    it "evaluates outer, inner and local groups once per leaf (not once per block), with stable metadata and frozen callback containers preserved" do
      # A once-per-block cache keyed by the shared Context would collapse
      # this trace to [:outer, :inner, :local, :local] for the second leaf.
      # Correct per-leaf evaluation produces the full sequence twice.
      trace = []
      contexts = []
      outer = { if: [->(ctx) { trace << :outer; contexts << ctx; true }].freeze }.freeze
      inner = { if: [->(ctx) { trace << :inner; true }].freeze }.freeze
      local = { if: [->(ctx) { trace << :local; true }].freeze }.freeze

      klass = Class.new do
        include PoroValidator.validator

        validates :address, **outer do
          validates :country, **inner do
            validates :code, presence: true, **local
            validates :zone, presence: true, **local
          end
        end
      end

      root = Struct.new(:address).new(
        Struct.new(:country).new(
          Struct.new(:code, :zone).new(nil, nil)
        )
      )
      validator = klass.new
      before_group_ids = klass.validations.validations.map { |v| v[:conditions].object_id }

      2.times do
        trace.clear
        contexts.clear
        expect(validator.valid?(root)).to be(false)
        expect(trace).to eq([:outer, :inner, :local, :outer, :inner, :local])
        expect(validator.errors.count).to eq(2)
        # Both leaves share the SAME Context: root entity, owning validator,
        # and errors -- not a per-leaf or per-nested-value context.
        expect(contexts.size).to eq(2)
        expect(contexts[0]).to be(contexts[1])
        expect(contexts[0].entity).to be(root)
        expect(contexts[0].context).to be(validator)
        expect(contexts[0].errors).to be(validator.errors)
      end

      # Condition-group metadata containers are the same objects across
      # repeated #valid? calls -- not rebuilt or duplicated per call.
      after_group_ids = klass.validations.validations.map { |v| v[:conditions].object_id }
      expect(after_group_ids).to eq(before_group_ids)

      # The caller's frozen Hashes and their frozen callback Arrays are
      # untouched: contents and frozen state are exactly as constructed.
      [outer, inner, local].each do |group|
        expect(group.frozen?).to be(true)
        expect(group.keys).to eq([:if])
        expect(group[:if].frozen?).to be(true)
        expect(group[:if].size).to eq(1)
      end
    end

    it "inheritance reuses the same per-leaf group without duplicating callback invocations" do
      trace = []
      outer_condition = ->(_ctx) { trace << :outer; true }

      parent = Class.new do
        include PoroValidator.validator

        validates :address, if: outer_condition do
          validates :line1, presence: true
        end
      end

      child = Class.new(parent)

      entity = customer_class.new("x", address_class.new(nil, nil))
      trace.clear
      expect(child.new.valid?(entity)).to be(false)
      # One leaf copied by inheritance, evaluated once -- not duplicated.
      expect(trace).to eq([:outer])
      expect(child.validations.validations.length).to eq(1)
    end
  end

  context "retained ignored non-condition options on block declarations" do
    it "ignores non-condition keys passed alongside a block, as before this change" do
      klass = Class.new do
        include PoroValidator.validator

        validates :address, if: ->(_c) { true }, message: "ignored", allow_blank: true do
          validates :line1, presence: true
        end
      end

      entity = customer_class.new("x", address_class.new(nil, nil))
      validator = klass.new
      expect(validator.valid?(entity)).to be(false)
      # The custom :message option on the block itself has no effect; the
      # leaf's own default presence message is used, unchanged from before.
      expect(validator.errors.on([:address, :line1])).to eq(["is not present"])
    end

    it "flat declarations (no block) continue to forward all options unchanged" do
      klass = Class.new do
        include PoroValidator.validator

        validates :name, presence: { message: "custom message" }
      end

      validator = klass.new
      validator.valid?(customer_class.new(nil, nil))
      expect(validator.errors.on(:name)).to eq(["custom message"])
    end
  end
end
