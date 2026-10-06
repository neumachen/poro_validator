require 'spec_helper'

RSpec.describe PoroValidator::Validators::NumericValidator do
  include SpecHelpers::ValidatorTestMacros

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :section, numeric: 1..10
        validates :amount, numeric: 1..10
        validates :cap, numeric: { extremum: 5 }
        validates :bonus, numeric: { min: 10, max: 20 }
        validates :price, numeric: { min: 10 }
        validates :interest, numeric: { max: 20 }
        validates :rate, numeric: 1..10, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          section: 'aa',
          amount: 11,
          cap: 6,
          bonus: 21,
          price: 9,
          interest: 21,
          rate: 11
        )
      end

      let(:expected_errors) do
        {
          "section"  => ["is not an integer or float type"],
          "amount"   => ["does not match the numeric options: {:in=>1..10}"],
          "cap"      => ["does not match the numeric options: {:extremum=>5}"],
          "bonus"    => ["does not match the numeric options: {:max=>20}"],
          "price"    => ["does not match the numeric options: {:min=>10}"],
          "interest" => ["does not match the numeric options: {:max=>20}"],
        }
      end

      skip_attr_unmet_condition do
        let(:attr) { :rate }

        it "expects the attribute is not valid" do
          expect(entity.public_send(attr).between?(1, 10)).to be_falsey
        end
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          section: 1,
          amount: 10,
          cap: 5,
          bonus: 11,
          price: 11,
          interest: 19,
          rate: 11
        )
      end
    end

    context "invalid option" do
      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :section, numeric: { mama: 1..10, in: 5..10 }
        end.new
      end

      it "raises a ::PoroValidator::Exceptions" do
        expect { subject.valid?({ section: 12 }) }.to raise_error(
          ::PoroValidator::InvalidValidator
        )
      end
    end

    context "invalid option value" do
      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :section, numeric: { in: "a" }
        end.new
      end

      it "raises a ::PoroValidator::Exceptions" do
        expect { subject.valid?({ section: 12 }) }.to raise_error(
          ::PoroValidator::InvalidValidator
        )
      end
    end

    # Boundaries not covered above, including integer options beyond the old
    # Fixnum range.
    context "integer option values" do
      subject(:validator) do
        Class.new do
          include PoroValidator.validator

          validates :bounded, numeric: { min: 10, max: 20 }
          validates :inclusive, numeric: 1..10
          validates :exclusive, numeric: 1...10
          validates :cap, numeric: { extremum: 5 }
          validates :negative, numeric: { min: -10, max: 0 }
          validates :large, numeric: { min: 2**64, max: 2**65 }
        end.new
      end

      expect_validator_to_be_valid("values at the lower bounds") do
        let(:entity) do
          OpenStruct.new(bounded: 10, exclusive: 1, negative: -10, large: 2**64)
        end
      end

      expect_validator_to_be_valid("values at the upper bounds") do
        let(:entity) do
          OpenStruct.new(bounded: 20, exclusive: 9, negative: 0, large: 2**65)
        end
      end

      expect_validator_to_be_invalid("values one below the lower bounds") do
        let(:entity) do
          OpenStruct.new(
            bounded: 9,
            inclusive: 0,
            exclusive: 0,
            cap: 4,
            negative: -11,
            large: 2**64 - 1
          )
        end

        let(:expected_errors) do
          {
            "bounded"   => ["does not match the numeric options: {:min=>10}"],
            "inclusive" => ["does not match the numeric options: {:in=>1..10}"],
            "exclusive" => ["does not match the numeric options: {:in=>1...10}"],
            "cap"       => ["does not match the numeric options: {:extremum=>5}"],
            "negative"  => ["does not match the numeric options: {:min=>-10}"],
            "large"     => ["does not match the numeric options: {:min=>#{2**64}}"]
          }
        end
      end

      expect_validator_to_be_invalid("values one above the upper bounds") do
        let(:entity) do
          OpenStruct.new(exclusive: 10, negative: 1, large: 2**65 + 1)
        end

        let(:expected_errors) do
          {
            "exclusive" => ["does not match the numeric options: {:in=>1...10}"],
            "negative"  => ["does not match the numeric options: {:max=>0}"],
            "large"     => ["does not match the numeric options: {:max=>#{2**65}}"]
          }
        end
      end

      expect_validator_to_be_valid("nil values") do
        let(:entity) do
          OpenStruct.new(
            bounded: nil,
            inclusive: nil,
            exclusive: nil,
            cap: nil,
            negative: nil,
            large: nil
          )
        end
      end
    end

    context "custom message metadata" do
      it "uses a literal message on a failing bound constraint" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 10, message: "too small" }
        end.new
        expect(validator.valid?(value: 5)).to be(false)
        expect(validator.errors.on(:value)).to eq(["too small"])
      end

      it "does not add an error when the constraint passes with a literal message" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 3, message: "too small" }
        end.new
        expect(validator.valid?(value: 5)).to be(true)
        expect(validator.errors.on(:value)).to be_nil
      end

      it "uses a Symbol message passed through Errors#add with the constraint options" do
        saved_opts = nil
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        @_prior_numeric_test = msgs[:numeric_test]
        @_had_numeric_test = msgs.key?(:numeric_test)
        PoroValidator.configure do |c|
          c.message.set(:numeric_test, ->(opts) { saved_opts = opts; "failed bounds" })
        end
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 10, message: :numeric_test }
        end.new
        expect(validator.valid?(value: 5)).to be(false)
        expect(validator.errors.on(:value)).to eq(["failed bounds"])
        expect(saved_opts).to eq(min: 10)
      ensure
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages)
        if msgs
          if @_had_numeric_test
            msgs[:numeric_test] = @_prior_numeric_test
          else
            msgs.delete(:numeric_test)
          end
        end
      end

      it "falls back to :numeric when message is nil or false" do
        [nil, false].each do |msg|
          validator = Class.new do
            include PoroValidator.validator
            validates :value, numeric: { min: 10, message: msg }
          end.new
          expect(validator.valid?(value: 5)).to be(false)
          expect(validator.errors.on(:value)).to eq(["does not match the numeric options: {:min=>10}"])
        end
      end

      it "falls back to :numeric when message is absent" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 10 }
        end.new
        expect(validator.valid?(value: 5)).to be(false)
        expect(validator.errors.on(:value)).to eq(["does not match the numeric options: {:min=>10}"])
      end

      it "does not add a constraint for a message-only declaration" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { message: "custom" }
        end.new
        expect(validator.valid?(value: "abc")).to be(false)
        expect(validator.errors.on(:value)).to eq(["is not an integer or float type"])
      end

      it "reports two messages for two failed constraints with metadata present" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { in: 5..10, extremum: 5, message: "bad" }
        end.new
        expect(validator.valid?(value: 15)).to be(false)
        expect(validator.errors.on(:value)).to eq(["bad", "bad"])
      end

      it "preserves constraint order with metadata first in the Hash" do
        saved = []
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        @_prior_order_meta = msgs[:order_meta]
        @_had_order_meta = msgs.key?(:order_meta)
        PoroValidator.configure do |c|
          c.message.set(:order_meta, ->(opts) { saved << opts; "meta:#{opts.keys.first}" })
        end
        v = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { message: :order_meta, in: 5..10, extremum: 5 }
        end.new
        expect(v.valid?(value: 15)).to be(false)
        # in: fires first (insertion order), then extremum
        expect(saved).to eq([{in: 5..10}, {extremum: 5}])
        expect(v.errors.on(:value)).to eq(["meta:in", "meta:extremum"])
        expect(v.errors.count).to eq(2)
      ensure
        cfg2 = PoroValidator.configuration.message
        msgs2 = cfg2.instance_variable_get(:@messages)
        if msgs2
          if @_had_order_meta
            msgs2[:order_meta] = @_prior_order_meta
          else
            msgs2.delete(:order_meta)
          end
        end
      end

      it "respects max-then-min declared order" do
        saved = []
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        @_prior_maxmin = msgs[:maxmin]
        @_had_maxmin = msgs.key?(:maxmin)
        PoroValidator.configure do |c|
          c.message.set(:maxmin, ->(opts) { saved << opts; "mxmn:#{opts.keys.first}" })
        end
        v = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { max: 5, min: 10, message: :maxmin }
        end.new
        v.valid?(value: 7)
        expect(saved).to eq([{max: 5}, {min: 10}])
        expect(v.errors.on(:value)).to eq(["mxmn:max", "mxmn:min"])
      ensure
        cfg2 = PoroValidator.configuration.message
        msgs2 = cfg2.instance_variable_get(:@messages)
        if msgs2
          if @_had_maxmin
            msgs2[:maxmin] = @_prior_maxmin
          else
            msgs2.delete(:maxmin)
          end
        end
      end

      it "still raises InvalidValidator for an unknown key alongside message" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 10, message: "custom", foo: 1 }
        end.new
        expect { validator.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "preserves a frozen options Hash" do
        opts = { min: 10, message: "too small" }.freeze
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: opts
        end.new
        expect(validator.valid?(value: 5)).to be(false)
        expect(validator.errors.on(:value)).to eq(["too small"])
        expect(opts).to eq({ min: 10, message: "too small" })
      end

      it "allows valid-after-invalid reuse" do
        validator = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 10, message: "too small" }
        end.new
        expect(validator.valid?(value: 5)).to be(false)
        expect(validator.valid?(value: 15)).to be(true)
        expect(validator.valid?(value: 5)).to be(false)
      end
    end

    context "string numeric comparison" do
      it "treats '5' as valid with min:3" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 3 } }.new
        expect(v.valid?(value: "5")).to be(true)
      end

      it "treats '5' as valid with extremum:5" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 5 } }.new
        expect(v.valid?(value: "5")).to be(true)
      end

      it "treats '5' as valid with in:5..10" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 5..10 } }.new
        expect(v.valid?(value: "5")).to be(true)
      end

      it "treats '1,234' as valid with max:2000" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 2000 } }.new
        expect(v.valid?(value: "1,234")).to be(true)
      end

      it "treats '010' as ten with extremum:10" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 10 } }.new
        expect(v.valid?(value: "010")).to be(true)
      end

      it "treats '08' as eight with extremum:8" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 8 } }.new
        expect(v.valid?(value: "08")).to be(true)
      end

      it "rejects '0.1' with min:0.1 under Policy B" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 0.1 } }.new
        expect(v.valid?(value: "0.1")).to be(false)
        expect(v.errors.on(:value)).to_not be_empty
      end

      it "accepts '0.1' with max:0.1 under Policy B" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 0.1 } }.new
        expect(v.valid?(value: "0.1")).to be(true)
      end

      it "rejects '0.1' with extremum:0.1 under Policy B" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 0.1 } }.new
        expect(v.valid?(value: "0.1")).to be(false)
      end

      it "rejects '0.1' with in:[0.1] under Policy B" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [0.1] } }.new
        expect(v.valid?(value: "0.1")).to be(false)
      end

      it "accepts native Float 0.1 with extremum:0.1" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 0.1 } }.new
        expect(v.valid?(value: 0.1)).to be(true)
      end

      it "accepts native Float 0.1 with in:[0.1]" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [0.1] } }.new
        expect(v.valid?(value: 0.1)).to be(true)
      end

      it "accepts '0.1' with in:0.0...0.1" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 0.0...0.1 } }.new
        expect(v.valid?(value: "0.1")).to be(true)
      end

      it "rejects '9007199254740993.0' with max:9007199254740992.0" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 9007199254740992.0 } }.new
        expect(v.valid?(value: "9007199254740993.0")).to be(false)
      end

      it "rejects '9007199254740993.0' with in:[9007199254740992.0]" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [9007199254740992.0] } }.new
        expect(v.valid?(value: "9007199254740993.0")).to be(false)
      end

      it "accepts '0.3' with max:(0.1+0.2) under Policy B" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: (0.1 + 0.2) } }.new
        expect(v.valid?(value: "0.3")).to be(true)
      end

      it "rejects '0.3' with extremum:(0.1+0.2) under Policy B" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: (0.1 + 0.2) } }.new
        expect(v.valid?(value: "0.3")).to be(false)
      end

      it "rejects tiny decimal excess over 1 with max:1.0" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 1.0 } }.new
        expect(v.valid?(value: "1.00000000000000000000000000000000000001")).to be(false)
      end

      it "rejects decimal beyond Float::MAX with max:Float::MAX" do
        huge = "1" + "0" * 400 + ".0"
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: Float::MAX } }.new
        expect(v.valid?(value: huge)).to be(false)
      end

      it "rejects 9007199254740993.0 with finite upper-bounded Float range" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 0.0..9007199254740992.0 } }.new
        expect(v.valid?(value: "9007199254740993.0")).to be(false)
      end
    end

    context "Policy B bound types" do
      it "accepts 5 with in:1..5.5 (mixed Integer/Float range)" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 1..5.5 } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "accepts 5 with in:1.5..6 (mixed Float/Integer range)" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 1.5..6 } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "rejects 5 with in:[] (empty Array)" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [] } }.new
        expect(v.valid?(value: 5)).to be(false)
      end

      it "rejects Rational range endpoint" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: Rational(1,2)..Rational(11,2) } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "rejects infinite range endpoint" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 0.0..Float::INFINITY } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "rejects NaN as a bound" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: Float::NAN } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "rejects constructible String range when reached" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 'a'..'z' } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "skips String range for nil input" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 'a'..'z' } }.new
        expect(v.valid?(value: nil)).to be(true)
      end

      it "rejects Range subclass as configuration" do
        custom_range = Class.new(Range).new(1, 10)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: custom_range } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "rejects Array subclass as configuration" do
        custom_array = Class.new(Array).new([1, 5, 10])
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: custom_array } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "accepts beginless range" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: ..10 } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "accepts endless range" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 1.. } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "accepts fully unbounded range" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: nil..nil } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "accepts 5 with in:[1, 2.5, 5] (mixed Integer/Float Array)" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [1, 2.5, 5] } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "rejects mixed-member Array with non-numeric element" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [1, "a"] } }.new
        expect { v.valid?(value: 5) }.to raise_error(PoroValidator::InvalidValidator)
      end

      it "rejects custom object with to_s '5' and range bound (legacy behavior)" do
        obj = Object.new
        def obj.to_s; '5'; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 1..10 } }.new
        expect(v.valid?(value: obj)).to be(false)
        expect(v.errors.on(:value)).to_not be_empty
      end

      it "accepts custom object with to_s '5' and no bounds (unchanged)" do
        obj = Object.new
        def obj.to_s; '5'; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: true }.new
        expect(v.valid?(value: obj)).to be(true)
      end

      it "treats String subclass input same as String for bounds" do
        subclass = Class.new(String)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 3 } }.new
        expect(v.valid?(value: subclass.new("5"))).to be(true)
      end

      it "treats String subclass input with extremum" do
        subclass = Class.new(String)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 10 } }.new
        expect(v.valid?(value: subclass.new("010"))).to be(true)
      end

      it "treats frozen String subclass input" do
        subclass = Class.new(String)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: 1..10 } }.new
        expect(v.valid?(value: subclass.new("5").freeze)).to be(true)
      end

      it "treats String subclass with in:[5]" do
        subclass = Class.new(String)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { in: [5] } }.new
        expect(v.valid?(value: subclass.new("5"))).to be(true)
      end

      it "String subclass '0.1' obeys Policy B max:0.1" do
        subclass = Class.new(String)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 0.1 } }.new
        expect(v.valid?(value: subclass.new("0.1"))).to be(true)
      end

      it "String subclass '0.1' obeys Policy B min:0.1" do
        subclass = Class.new(String)
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 0.1 } }.new
        expect(v.valid?(value: subclass.new("0.1"))).to be(false)
      end

      it "String subclass preserves caller entity identity" do
        subclass = Class.new(String)
        input = subclass.new("5")
        entity = {value: input}
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 3 } }.new
        v.valid?(entity)
        expect(entity[:value]).to be(input)
        expect(entity[:value]).to eq("5")
        expect(entity[:value]).to be_a(subclass)
        expect(entity[:value]).to be_frozen if input.frozen?
      end

      it "propagates ArgumentError from custom >= operator" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.>=(other); raise ArgumentError, "comparison sentinel"; end
        def obj.<=(other); false; end
        def obj.==(other); false; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 3 } }.new
        expect { v.valid?(value: obj) }.to raise_error(ArgumentError, "comparison sentinel")
      end

      it "propagates ArgumentError from custom <= operator" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.<=(other); raise ArgumentError, "comparison sentinel"; end
        def obj.>=(other); false; end
        def obj.==(other); false; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 10 } }.new
        expect { v.valid?(value: obj) }.to raise_error(ArgumentError, "comparison sentinel")
      end

      it "propagates ArgumentError from custom == operator" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.==(other); raise ArgumentError, "comparison sentinel"; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 5 } }.new
        expect { v.valid?(value: obj) }.to raise_error(ArgumentError, "comparison sentinel")
      end

      it "custom operator returning false is still a validation failure" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.>=(other); false; end
        def obj.<=(other); false; end
        def obj.==(other); false; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 3 } }.new
        expect(v.valid?(value: obj)).to be(false)
        expect(v.errors.on(:value)).to_not be_empty
      end

      it "missing >= raises NoMethodError" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.<=(other); false; end
        def obj.==(other); false; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: 3 } }.new
        expect { v.valid?(value: obj) }.to raise_error(NoMethodError)
      end

      it "missing <= raises NoMethodError" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.>=(other); false; end
        def obj.==(other); false; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { max: 10 } }.new
        expect { v.valid?(value: obj) }.to raise_error(NoMethodError)
      end

      it "NoMethodError raised inside custom == propagates" do
        obj = Object.new
        def obj.to_s; '5'; end
        def obj.==(other); raise NoMethodError, "internal bug"; end
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { extremum: 5 } }.new
        expect { v.valid?(value: obj) }.to raise_error(NoMethodError, "internal bug")
      end
    end

    context "validation timing and preservation" do
      it "skips nil even with invalid bounds" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: Float::NAN } }.new
        expect(v.valid?(value: nil)).to be(true)
      end

      it "returns format error for malformed input even with invalid bounds" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { min: Float::NAN } }.new
        expect(v.valid?(value: "abc")).to be(false)
        expect(v.errors.on(:value)).to eq(["is not an integer or float type"])
      end

      it "valid numeric input with message-only options" do
        v = Class.new { include PoroValidator.validator; validates :value, numeric: { message: "custom" } }.new
        expect(v.valid?(value: 5)).to be(true)
      end

      it "distinguishable constraint-order: min fires before max" do
        saved = []
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        prior = msgs[:order_track]
        had_order_track = msgs.key?(:order_track)
        PoroValidator.configure do |c|
          c.message.set(:order_track, ->(opts) { saved << opts; "trk:#{opts.keys.first}" })
        end
        v = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 10, max: 5, message: :order_track }
        end.new
        v.valid?(value: 7)
        # Both constraints fail. Options iteration is in insertion order:
        # min before max. The callback receives {min: 10} then {max: 5}.
        expect(saved).to eq([{min: 10}, {max: 5}])
        expect(v.errors.on(:value)).to eq(["trk:min", "trk:max"])
      ensure
        cfg2 = PoroValidator.configuration.message
        msgs2 = cfg2.instance_variable_get(:@messages)
        if msgs2
          if had_order_track
            msgs2[:order_track] = prior
          else
            msgs2.delete(:order_track)
          end
        end
      end

      it "preserves frozen options Hash" do
        opts = { min: 3, max: 10 }.freeze
        v = Class.new { include PoroValidator.validator; validates :value, numeric: opts }.new
        expect(v.valid?(value: "5")).to be(true)
        expect(opts).to eq({ min: 3, max: 10 })
      end

      it "earlier failing constraint stores error before later invalid option raises" do
        saved = nil
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        prior = msgs[:late_check]
        had_late_check = msgs.key?(:late_check)
        PoroValidator.configure do |c|
          c.message.set(:late_check, ->(opts) { saved = opts; "bad" })
        end
        v = Class.new do
          include PoroValidator.validator
          validates :value, numeric: { min: 5, in: 'a'..'z', message: :late_check }
        end.new
        expect { v.valid?(value: 3) }.to raise_error(PoroValidator::InvalidValidator)
        expect(saved).to eq({min: 5})
        expect(v.errors.on(:value)).to eq(["bad"])
      ensure
        cfg2 = PoroValidator.configuration.message
        msgs2 = cfg2.instance_variable_get(:@messages)
        if msgs2
          if had_late_check
            msgs2[:late_check] = prior
          else
            msgs2.delete(:late_check)
          end
        end
      end
    end
  end
end
