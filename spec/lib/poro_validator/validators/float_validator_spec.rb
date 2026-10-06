require 'spec_helper'

RSpec.describe PoroValidator::Validators::FloatValidator do
  describe "#validate" do
    context "format boundary tests" do
      context "valid float values" do
        [5.00, "500.00", -1.00, "+3,000.000", 0.5, "0.5",
         "-300.00", "+400.00", "1,000.50"].each do |value|
          it "accepts valid float: #{value.inspect}" do
            validator = Class.new do
              include PoroValidator.validator
              validates :amount, float: true
            end.new
            expect(validator.valid?(amount: value)).to be(true)
            expect(validator.errors.on(:amount)).to be_nil
          end
        end
      end

      context "invalid float values" do
        [5, "500", -1, "+3,000", ".5",
         "-300", "+400", "aaa", "1,23.50", "1.00.00",
         "+", "-", "", "1,00.50"].each do |value|
          it "rejects invalid float: #{value.inspect}" do
            validator = Class.new do
              include PoroValidator.validator
              validates :amount, float: true
            end.new
            expect(validator.valid?(amount: value)).to be(false)
            expect(validator.errors.on(:amount)).to eq(["is not a float"])
          end
        end
      end
    end

    context "option validation" do
      it "raises PoroValidator::InvalidValidator when :min is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { min: 5 }
        end.new
        expect { validator.valid?(amount: 10.0) }.to raise_error(
          PoroValidator::InvalidValidator,
          /FloatValidator does not support numeric options/
        )
      end

      it "raises PoroValidator::InvalidValidator when :max is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { max: 10 }
        end.new
        expect { validator.valid?(amount: 5.0) }.to raise_error(
          PoroValidator::InvalidValidator,
          /FloatValidator does not support numeric options/
        )
      end

      it "raises PoroValidator::InvalidValidator when :in is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { in: 1.0..10.0 }
        end.new
        expect { validator.valid?(amount: 5.0) }.to raise_error(
          PoroValidator::InvalidValidator,
          /FloatValidator does not support numeric options/
        )
      end

      it "raises PoroValidator::InvalidValidator when :extremum is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { extremum: 5.0 }
        end.new
        expect { validator.valid?(amount: 5.0) }.to raise_error(
          PoroValidator::InvalidValidator,
          /FloatValidator does not support numeric options/
        )
      end

      it "does NOT raise when :message is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { message: "must be decimal" }
        end.new
        expect { validator.valid?(amount: 5.0) }.not_to raise_error
      end

      it "does NOT raise when :if condition is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { if: proc { true } }
        end.new
        expect { validator.valid?(amount: 5.0) }.not_to raise_error
      end

      it "does NOT raise when :unless condition is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { unless: proc { false } }
        end.new
        expect { validator.valid?(amount: 5.0) }.not_to raise_error
      end
    end

    context "custom message" do
      it "uses a literal message on invalid value" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { message: "must be decimal" }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["must be decimal"])
      end

      it "uses a Symbol message resolved through configuration" do
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        @_prior_float_test = msgs[:float_test]
        @_had_float_test = msgs.key?(:float_test)
        PoroValidator.configure do |c|
          c.message.set(:float_test, -> { "custom symbol message" })
        end
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { message: :float_test }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["custom symbol message"])
      ensure
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages)
        if msgs
          if @_had_float_test
            msgs[:float_test] = @_prior_float_test
          else
            msgs.delete(:float_test)
          end
        end
      end

      it "falls back to :float when message is nil" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { message: nil }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end

      it "falls back to :float when message is false" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { message: false }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end

      it "falls back to :float when message is absent" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end
    end

    context "string subclass tests" do
      it "accepts String subclass with valid float format" do
        subclass = Class.new(String)
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: subclass.new("500.00"))).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "rejects String subclass with invalid float format" do
        subclass = Class.new(String)
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: subclass.new("abc"))).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end

      it "accepts frozen String subclass input" do
        subclass = Class.new(String)
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: subclass.new("500.00").freeze)).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end
    end

    context "custom object tests" do
      it "accepts object with #to_s returning valid float format" do
        obj = Object.new
        def obj.to_s; "500.00"; end
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: obj)).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "rejects object with #to_s returning invalid float format" do
        obj = Object.new
        def obj.to_s; "abc"; end
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: obj)).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end

      it "preserves entity identity (value not mutated)" do
        obj = Object.new
        def obj.to_s; "500.00"; end
        entity = { amount: obj }
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        validator.valid?(entity)
        expect(entity[:amount]).to be(obj)
      end
    end

    context "nil and condition tests" do
      it "skips validation for nil values" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: nil)).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "skips validation when :if condition returns false" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { if: proc { false } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "skips validation when :unless condition returns true" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { unless: proc { true } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "validates when :if condition returns true" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { if: proc { true } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end

      it "validates when :unless condition returns false" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: { unless: proc { false } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not a float"])
      end
    end

    context "reuse tests" do
      it "can be reused across multiple valid? calls" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        expect(validator.valid?(amount: 5.0)).to be(true)
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.valid?(amount: 10.0)).to be(true)
        expect(validator.valid?(amount: "xyz")).to be(false)
      end

      it "can be reused across multiple entities" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, float: true
        end.new
        entity1 = { amount: 5.0 }
        entity2 = { amount: "abc" }
        entity3 = { amount: 10.0 }
        expect(validator.valid?(entity1)).to be(true)
        expect(validator.valid?(entity2)).to be(false)
        expect(validator.valid?(entity3)).to be(true)
      end
    end
  end
end
