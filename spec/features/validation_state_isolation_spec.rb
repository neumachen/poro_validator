require 'spec_helper'

# The rule objects created by `validates` belong to the validator class, so
# every instance of the class, and of its subclasses, runs the same ones. These
# examples overlap two calls on separate instances: deterministically, with a
# worker thread that stops inside a rule until the example lets it continue,
# or synchronously, when a rule's input validates through another instance.
RSpec.describe "Validation state is kept per call", :aggregate_failures, type: :feature do
  let(:named) { Struct.new(:name) }

  def presence_validator_class
    Class.new do
      include PoroValidator.validator

      validates :name, presence: true
    end
  end

  # An object whose #name runs the block.
  def entity_reading(&reader)
    Object.new.tap { |entity| entity.define_singleton_method(:name, &reader) }
  end

  # Validates in a worker thread that stops where the entity calls the pause
  # lambda given to build_entity. Runs the block while the worker is stopped,
  # then lets it finish and returns its result. The worker is always released
  # and joined, even when the block or an expectation fails.
  def validate_in_worker(validator, build_entity)
    paused = Queue.new
    resume = Queue.new
    entity = build_entity.call(lambda { paused << :paused; resume.pop })
    worker = Thread.new do
      Thread.current.report_on_exception = false
      begin
        validator.valid?(entity)
      ensure
        paused << :finished
      end
    end

    expect(paused.pop).to eq(:paused)
    yield
    resume << :go
    worker.value
  ensure
    if worker
      resume << :go
      begin
        worker.join
      rescue StandardError
        nil # worker.value above re-raises it where it matters
      end
    end
  end

  # A (entity invalid, stopped inside its rule) and B (entity valid) run on
  # separate instances; B runs to completion while A is stopped.
  def overlap(a, b)
    outcome = {}
    outcome[:a] = validate_in_worker(a, lambda { |pause| entity_reading { pause.call; nil } }) do
      outcome[:b] = b.valid?(named.new("present"))
      outcome[:b_errors] = b.errors
      outcome[:b_messages] = b.errors.full_messages
    end
    outcome
  end

  def expect_isolated(a, b, outcome)
    expect(outcome[:a]).to be(false)
    expect(a.errors.full_messages).to eq(["name is not present"])
    expect(outcome[:b]).to be(true)
    expect(outcome[:b_messages]).to eq([])
    expect(b.errors).to be(outcome[:b_errors])
    expect(b.errors.full_messages).to eq([])
    expect(a.errors).not_to be(b.errors)
  end

  context "when two instances of one class overlap" do
    it "keeps each call's result and errors" do
      klass = presence_validator_class
      a = klass.new
      b = klass.new

      expect_isolated(a, b, overlap(a, b))
    end
  end

  context "when a parent and a child class share inherited rules" do
    let(:parent) { presence_validator_class }
    let(:child) { Class.new(parent) }

    it "keeps them separate while a parent instance is stopped" do
      a = parent.new
      b = child.new

      expect_isolated(a, b, overlap(a, b))
    end

    it "keeps them separate while a child instance is stopped" do
      a = child.new
      b = parent.new

      expect_isolated(a, b, overlap(a, b))
    end
  end

  context "when an attribute reader validates through another instance" do
    it "keeps both calls' results and errors on the same thread" do
      klass = presence_validator_class
      a = klass.new
      b = klass.new
      present = named.new("present")
      outcome = {}
      reentrant = entity_reading do
        outcome[:b] = b.valid?(present)
        outcome[:b_errors] = b.errors
        outcome[:b_messages] = b.errors.full_messages
        nil
      end

      outcome[:a] = a.valid?(reentrant)

      expect_isolated(a, b, outcome)
    end
  end

  context "controls that were already correct" do
    it "validates serial calls on separate instances" do
      klass = presence_validator_class
      a = klass.new
      b = klass.new

      expect(a.valid?(named.new(nil))).to be(false)
      expect(b.valid?(named.new("present"))).to be(true)
      expect(a.errors.full_messages).to eq(["name is not present"])
      expect(b.errors.full_messages).to eq([])
    end

    it "gives each serial call on one instance fresh errors" do
      validator = presence_validator_class.new

      expect(validator.valid?(named.new(nil))).to be(false)
      first_errors = validator.errors
      expect(validator.valid?(named.new("present"))).to be(true)

      expect(validator.errors).not_to be(first_errors)
      expect(validator.errors.full_messages).to eq([])
      expect(first_errors.full_messages).to eq(["name is not present"])
    end

    it "keeps independently declared classes separate when they overlap" do
      a = presence_validator_class.new
      b = presence_validator_class.new

      expect_isolated(a, b, overlap(a, b))
    end
  end

  context "with composed validators" do
    it "keeps each outer call's errors while the composed validator is stopped" do
      address_validator = presence_validator_class
      klass = Class.new do
        include PoroValidator.validator

        validates :address, with: address_validator
      end
      holder = Struct.new(:address)
      a = klass.new
      b = klass.new
      b_result = nil

      a_result = validate_in_worker(a, lambda { |pause| holder.new(entity_reading { pause.call; nil }) }) do
        b_result = b.valid?(holder.new(named.new("present")))
      end

      expect(a_result).to be(false)
      expect(a.errors.full_messages).to eq(["{:address=>:name} is not present"])
      expect(b_result).to be(true)
      expect(b.errors.full_messages).to eq([])
    end
  end

  context "with a custom rule" do
    # Follows the README's custom validator: a BaseClass subclass under
    # PoroValidator::Validators that implements #validate and uses the
    # context, errors and value helpers. It records what they return before
    # and after the entity's #during_validation, where another call can run.
    let(:recording_rule) do
      Class.new(PoroValidator::Validators::BaseClass) do
        def validate(attribute, value, options)
          before = { context: context, errors: errors, entity: context.entity, options: options }
          context.entity.during_validation
          options[:log] << before.merge(
            context_after: context, errors_after: errors,
            value_after: self.value, options_after: options
          )
          errors.add(attribute, "is not accepted") unless value == "accepted"
        end
      end
    end
    let(:options) { { log: [] } }
    let(:klass) do
      rule_options = options
      Class.new do
        include PoroValidator.validator

        validates :name, recording: rule_options
      end
    end

    before do
      stub_const("PoroValidator::Validators::RecordingValidator", recording_rule)
    end

    # An entity whose #during_validation runs the block, if one is given.
    def recording_entity(name_value, &during)
      Object.new.tap do |entity|
        entity.define_singleton_method(:name) { name_value }
        entity.define_singleton_method(:during_validation) { during && during.call }
      end
    end

    def expect_own_state(record, validator, entity, value)
      expect(record[:entity]).to be(entity)
      expect(record[:context_after]).to be(record[:context])
      expect(record[:errors]).to be(validator.errors)
      expect(record[:errors_after]).to be(validator.errors)
      expect(record[:value_after]).to eq(value)
      expect(record[:options]).to be(options)
      expect(record[:options_after]).to be(options)
    end

    it "sees its own state when another instance validates inside it" do
      a = klass.new
      b = klass.new
      accepted = recording_entity("accepted")
      b_result = nil
      rejected = recording_entity("rejected") { b_result = b.valid?(accepted) }

      expect(a.valid?(rejected)).to be(false)
      expect(b_result).to be(true)
      expect(a.errors.full_messages).to eq(["name is not accepted"])
      expect(b.errors.full_messages).to eq([])

      b_record, a_record = options[:log]
      expect_own_state(a_record, a, rejected, "rejected")
      expect_own_state(b_record, b, accepted, "accepted")
    end

    it "sees its own state while another instance validates" do
      a = klass.new
      b = klass.new
      accepted = recording_entity("accepted")
      rejected = nil
      b_result = nil

      a_result = validate_in_worker(a, lambda { |pause| rejected = recording_entity("rejected") { pause.call } }) do
        b_result = b.valid?(accepted)
      end

      expect(a_result).to be(false)
      expect(b_result).to be(true)
      expect(a.errors.full_messages).to eq(["name is not accepted"])
      expect(b.errors.full_messages).to eq([])

      b_record, a_record = options[:log]
      expect_own_state(a_record, a, rejected, "rejected")
      expect_own_state(b_record, b, accepted, "accepted")
    end

    it "propagates an error raised inside it, and later calls stay correct" do
      failing = recording_entity("rejected") { raise ArgumentError, "hook failed" }

      expect { klass.new.valid?(failing) }.to raise_error(ArgumentError, "hook failed")

      a = klass.new
      b = klass.new
      expect(a.valid?(recording_entity("rejected"))).to be(false)
      expect(b.valid?(recording_entity("accepted"))).to be(true)
      expect(a.errors.full_messages).to eq(["name is not accepted"])
      expect(b.errors.full_messages).to eq([])
    end
  end

  context "when a call raises" do
    it "propagates a reader's error, and later calls stay correct" do
      klass = presence_validator_class
      failing = entity_reading { raise ArgumentError, "reader failed" }

      expect { klass.new.valid?(failing) }.to raise_error(ArgumentError, "reader failed")

      valid = klass.new
      invalid = klass.new
      expect(valid.valid?(named.new("present"))).to be(true)
      expect(invalid.valid?(named.new(nil))).to be(false)
      expect(valid.errors.full_messages).to eq([])
      expect(invalid.errors.full_messages).to eq(["name is not present"])
    end

    it "keeps the outer call's errors when a call nested inside it raises" do
      klass = presence_validator_class
      a = klass.new
      b = klass.new
      failing = entity_reading { raise ArgumentError, "nested reader failed" }
      rescued = nil
      outer = entity_reading do
        begin
          b.valid?(failing)
        rescue ArgumentError => error
          rescued = error
        end
        nil
      end

      expect(a.valid?(outer)).to be(false)
      expect(rescued.message).to eq("nested reader failed")
      expect(a.errors.full_messages).to eq(["name is not present"])
      expect(b.valid?(named.new("present"))).to be(true)
      expect(b.errors.full_messages).to eq([])
    end
  end

  context "compatibility of custom rules" do
    it "keeps a custom rule's own state from one call to the next" do
      counting_rule = Class.new(PoroValidator::Validators::BaseClass) do
        def validate(attribute, value, options)
          @calls = (@calls || 0) + 1
          options[:log] << @calls
        end
      end
      stub_const("PoroValidator::Validators::CountingValidator", counting_rule)
      log = []
      klass = Class.new do
        include PoroValidator.validator

        validates :name, counting: { log: log }
      end

      klass.new.valid?(named.new("x"))
      klass.new.valid?(named.new("y"))
      Class.new(klass).new.valid?(named.new("z"))

      expect(log).to eq([1, 2, 3])
    end

    it "lets the helpers be used from a thread or fiber started inside the rule" do
      probing_rule = Class.new(PoroValidator::Validators::BaseClass) do
        def validate(attribute, value, options)
          from_thread = Thread.new { [context.entity, errors, self.value] }.value
          from_fiber = Fiber.new { [context.entity, errors, self.value] }.resume
          options[:log] << [[context.entity, errors, value], from_thread, from_fiber]
          errors.add(attribute, "is not accepted") unless value == "accepted"
        end
      end
      stub_const("PoroValidator::Validators::ProbingValidator", probing_rule)
      log = []
      validator = Class.new do
        include PoroValidator.validator

        validates :name, probing: { log: log }
      end.new
      entity = named.new("rejected")

      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.full_messages).to eq(["name is not accepted"])
      log.first.each do |entity_seen, errors_seen, value_seen|
        expect(entity_seen).to be(entity)
        expect(errors_seen).to be(validator.errors)
        expect(value_seen).to eq("rejected")
      end
    end
  end
end
