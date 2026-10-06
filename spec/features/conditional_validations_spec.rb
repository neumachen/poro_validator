require 'spec_helper'

# Conditions passed to `validates` apply to every rule in that declaration;
# conditions inside one rule's options apply to that rule only. The
# conditions here are one-argument lambdas, which the evaluator calls with
# the validation context.
RSpec.describe "Conditional validations", :aggregate_failures, type: :feature do
  let(:named) { Struct.new(:name) }
  let(:always) { ->(_context) { true } }
  let(:never) { ->(_context) { false } }
  let(:length_error) { "name does not match the length options: {:min=>5}" }
  let(:format_error) { "name does not match the pattern: /\\AOK\\z/" }
  let(:inclusion_error) { "name is not within the range of [\"OK\"]" }

  # Validates a name of "x", which fails the length (min 5), format (/\AOK\z/)
  # and inclusion (["OK"]) rules used here, against one `validates :name`
  # declaration. Returns the result and the error messages.
  def outcome_of(**declaration)
    klass = Class.new do
      include PoroValidator.validator

      validates :name, **declaration
    end
    validator = klass.new
    [validator.valid?(named.new("x")), validator.errors.full_messages]
  end

  context "with a condition inside one rule's options" do
    it "skips only that rule when its if is false, in either order" do
      expect(outcome_of(length: { min: 5, if: never }, format: { with: /\AOK\z/ })).
        to eq([false, [format_error]])
      expect(outcome_of(format: { with: /\AOK\z/ }, length: { min: 5, if: never })).
        to eq([false, [format_error]])
    end

    it "skips only that rule when its unless is true, in either order" do
      expect(outcome_of(length: { min: 5, unless: always }, format: { with: /\AOK\z/ })).
        to eq([false, [format_error]])
      expect(outcome_of(format: { with: /\AOK\z/ }, length: { min: 5, unless: always })).
        to eq([false, [format_error]])
    end

    it "applies an Array of conditions to that rule only" do
      expect(outcome_of(length: { min: 5, if: [always, never] }, format: { with: /\AOK\z/ })).
        to eq([false, [format_error]])
      expect(outcome_of(format: { with: /\AOK\z/ }, length: { min: 5, if: [always, never] })).
        to eq([false, [format_error]])
    end

    it "keeps three siblings' conditions apart in every order" do
      rules = {
        length:    { min: 5, if: never },
        format:    { with: /\AOK\z/, unless: never },
        inclusion: { in: ["OK"], if: always }
      }
      messages = { format: format_error, inclusion: inclusion_error }

      rules.to_a.permutation.each do |order|
        executed = order.map(&:first).select { |name| messages.key?(name) }
        expect(outcome_of(**order.to_h)).
          to eq([false, executed.map { |name| messages[name] }]), "order: #{order.map(&:first)}"
      end
    end
  end

  context "with a condition on the whole declaration" do
    it "applies it to every rule" do
      expect(outcome_of(length: { min: 5 }, format: { with: /\AOK\z/ }, if: never)).
        to eq([true, []])
      expect(outcome_of(length: { min: 5 }, format: { with: /\AOK\z/ }, if: always)).
        to eq([false, [length_error, format_error]])
    end

    it "still skips every rule when it fails, whatever the rules' own conditions" do
      expect(outcome_of(length: { min: 5, if: always }, format: { with: /\AOK\z/ }, if: never)).
        to eq([true, []])
    end

    it "keeps rules' own conditions local when it passes" do
      expect(outcome_of(length: { min: 5, if: never }, format: { with: /\AOK\z/ }, if: always)).
        to eq([false, [format_error]])
      expect(outcome_of(format: { with: /\AOK\z/ }, length: { min: 5, if: never }, if: always)).
        to eq([false, [format_error]])
    end
  end

  context "with caller-owned options" do
    it "leaves reused rule options intact across declarations and classes" do
      shared = { min: 5, if: never }
      condition = shared[:if]

      first = outcome_of(length: shared, format: { with: /\AOK\z/ })
      second = outcome_of(length: shared)
      klass = Class.new do
        include PoroValidator.validator

        validates :name, length: shared
        validates :name, length: shared, format: { with: /\AOK\z/ }
      end
      validator = klass.new

      expect(first).to eq([false, [format_error]])
      expect(second).to eq([true, []])
      expect(validator.valid?(named.new("x"))).to be(false)
      expect(validator.errors.full_messages).to eq([format_error])
      expect(shared.keys).to eq([:min, :if])
      expect(shared[:min]).to eq(5)
      expect(shared[:if]).to be(condition)
      expect(shared).not_to be_frozen
    end

    it "accepts frozen declaration and rule options that contain conditions" do
      rule_options = { min: 5, if: never }.freeze
      declaration = { length: rule_options, format: { with: /\AOK\z/ }.freeze, if: always }.freeze

      expect(outcome_of(**declaration)).to eq([false, [format_error]])
      expect(rule_options).to eq(min: 5, if: never)
    end

    it "keeps a rule's custom message together with its condition" do
      expect(outcome_of(format: { with: /\AOK\z/, message: "must be OK", if: always })).
        to eq([false, ["name must be OK"]])
      expect(outcome_of(length: { min: 5, if: never },
                        format: { with: /\AOK\z/, message: "must be OK", if: always })).
        to eq([false, ["name must be OK"]])
    end
  end

  context "controls" do
    it "keeps conditions per declaration, in subclasses and on repeated validation" do
      parent = Class.new do
        include PoroValidator.validator

        validates :name, length: { min: 5, if: ->(_context) { false } }
        validates :name, format: { with: /\AOK\z/ }
      end
      child = Class.new(parent) do
        validates :name, inclusion: { in: ["OK"], unless: ->(_context) { false } }
      end
      parent_validator = parent.new
      child_validator = child.new

      2.times do
        expect(parent_validator.valid?(named.new("x"))).to be(false)
        expect(parent_validator.errors.full_messages).to eq([format_error])
        expect(child_validator.valid?(named.new("x"))).to be(false)
        expect(child_validator.errors.full_messages).to eq([format_error, inclusion_error])
      end
    end

    it "still reports every unconditional rule's error in declaration order" do
      expect(outcome_of(length: { min: 5 }, format: { with: /\AOK\z/ })).
        to eq([false, [length_error, format_error]])
      expect(outcome_of(format: { with: /\AOK\z/ }, length: { min: 5 })).
        to eq([false, [format_error, length_error]])
    end
  end

  context "with option Hashes that have defaults or are Hash subclasses" do
    # A custom validator that reads its minimum from its options.
    let(:minimum_rule) do
      Class.new(PoroValidator::Validators::BaseClass) do
        def validate(attribute, value, options)
          minimum = options[:minimum]
          errors.add(attribute, "must be at least #{minimum}") if minimum && value < minimum
        end
      end
    end
    let(:amount) { Struct.new(:amount) }
    let(:rejects_5_accepts_15) { [[false, ["amount must be at least 10"]], [true, []]] }

    before do
      stub_const("PoroValidator::Validators::MinimumValidator", minimum_rule)
    end

    # Validates amounts 5 and 15 against `validates :amount, minimum: options`.
    def outcomes_for(options)
      klass = Class.new do
        include PoroValidator.validator

        validates :amount, minimum: options
      end
      [5, 15].map do |value|
        validator = klass.new
        [validator.valid?(amount.new(value)), validator.errors.full_messages]
      end
    end

    it "uses a default minimum" do
      options = Hash.new(10)
      options[:if] = always

      expect(outcomes_for(options)).to eq(rejects_5_accepts_15)
    end

    it "uses a minimum from a default Proc" do
      options = Hash.new { |_hash, key| 10 if key == :minimum }
      options[:if] = always

      expect(outcomes_for(options)).to eq(rejects_5_accepts_15)
    end

    it "uses a minimum from a Hash subclass's method and instance state" do
      options_class = Class.new(::Hash) do
        attr_accessor :floor

        def minimum
          floor
        end
      end
      options = options_class.new
      options.floor = 10
      options.default_proc = ->(hash, key) { hash.minimum if key == :minimum }
      options[:if] = always

      expect(outcomes_for(options)).to eq(rejects_5_accepts_15)
    end

    it "lets an explicit minimum override the default" do
      options = Hash.new(10)
      options[:minimum] = 3
      options[:if] = always

      expect(outcomes_for(options)).to eq([[true, []], [true, []]])
    end

    it "keeps the default when the condition is an unless, which keeps its meaning" do
      runs = Hash.new(10)
      runs[:unless] = never
      skipped = Hash.new(10)
      skipped[:unless] = always

      expect(outcomes_for(runs)).to eq(rejects_5_accepts_15)
      expect(outcomes_for(skipped)).to eq([[true, []], [true, []]])
    end

    it "keeps frozen, reused options with a default or default Proc intact across classes" do
      with_default = Hash.new(10)
      with_default[:if] = always
      with_default.freeze
      default_proc = ->(_hash, key) { 10 if key == :minimum }
      with_proc = {}
      with_proc.default_proc = default_proc
      with_proc[:unless] = never
      with_proc.freeze

      [with_default, with_proc].each do |options|
        2.times { expect(outcomes_for(options)).to eq(rejects_5_accepts_15) }
      end
      expect(with_default.keys).to eq([:if])
      expect(with_default[:if]).to be(always)
      expect(with_default.default).to eq(10)
      expect(with_proc.keys).to eq([:unless])
      expect(with_proc[:unless]).to be(never)
      expect(with_proc.default_proc).to be(default_proc)
      expect([with_default, with_proc]).to all(be_frozen)
    end
  end
end
