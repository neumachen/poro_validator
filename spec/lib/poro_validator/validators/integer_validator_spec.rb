require 'spec_helper'

RSpec.describe PoroValidator::Validators::IntegerValidator do
  describe "#validate" do
    context "format boundary tests" do
      context "valid integer values" do
        [5, "500", -1, +3000000, "-300", "+400", "1,000", "1,000,000",
         "9007199254740993"].each do |value|
          it "accepts valid integer: #{value.inspect}" do
            validator = Class.new do
              include PoroValidator.validator
              validates :amount, integer: true
            end.new
            expect(validator.valid?(amount: value)).to be(true)
            expect(validator.errors.on(:amount)).to be_nil
          end
        end
      end

      context "invalid integer values" do
        ["aa", 5.00, "+500.00", -1.0, +30.00, "-300.00", "+400.00",
         "1,23", "1,2345", "+", "-", "", "1,00", "10,00"].each do |value|
          it "rejects invalid integer: #{value.inspect}" do
            validator = Class.new do
              include PoroValidator.validator
              validates :amount, integer: true
            end.new
            expect(validator.valid?(amount: value)).to be(false)
            expect(validator.errors.on(:amount)).to eq(["is not an integer"])
          end
        end
      end
    end

    context "option validation" do
      it "raises PoroValidator::InvalidValidator when :min is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { min: 5 }
        end.new
        expect { validator.valid?(amount: 10) }.to raise_error(
          PoroValidator::InvalidValidator,
          /IntegerValidator does not support numeric options/
        )
      end

      it "raises PoroValidator::InvalidValidator when :max is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { max: 10 }
        end.new
        expect { validator.valid?(amount: 5) }.to raise_error(
          PoroValidator::InvalidValidator,
          /IntegerValidator does not support numeric options/
        )
      end

      it "raises PoroValidator::InvalidValidator when :in is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { in: 1..10 }
        end.new
        expect { validator.valid?(amount: 5) }.to raise_error(
          PoroValidator::InvalidValidator,
          /IntegerValidator does not support numeric options/
        )
      end

      it "raises PoroValidator::InvalidValidator when :extremum is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { extremum: 5 }
        end.new
        expect { validator.valid?(amount: 5) }.to raise_error(
          PoroValidator::InvalidValidator,
          /IntegerValidator does not support numeric options/
        )
      end

      it "does NOT raise when :message is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { message: "must be whole number" }
        end.new
        expect { validator.valid?(amount: 5) }.not_to raise_error
      end

      it "does NOT raise when :if condition is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { if: proc { true } }
        end.new
        expect { validator.valid?(amount: 5) }.not_to raise_error
      end

      it "does NOT raise when :unless condition is passed" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { unless: proc { false } }
        end.new
        expect { validator.valid?(amount: 5) }.not_to raise_error
      end
    end

    context "custom message" do
      it "uses a literal message on invalid value" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { message: "must be whole number" }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["must be whole number"])
      end

      it "uses a Symbol message resolved through configuration" do
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages) || {}
        @_prior_integer_test = msgs[:integer_test]
        @_had_integer_test = msgs.key?(:integer_test)
        PoroValidator.configure do |c|
          c.message.set(:integer_test, -> { "custom symbol message" })
        end
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { message: :integer_test }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["custom symbol message"])
      ensure
        cfg = PoroValidator.configuration.message
        msgs = cfg.instance_variable_get(:@messages)
        if msgs
          if @_had_integer_test
            msgs[:integer_test] = @_prior_integer_test
          else
            msgs.delete(:integer_test)
          end
        end
      end

      it "falls back to :integer when message is nil" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { message: nil }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end

      it "falls back to :integer when message is false" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { message: false }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end

      it "falls back to :integer when message is absent" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end
    end

    context "string subclass tests" do
      it "accepts String subclass with valid integer format" do
        subclass = Class.new(String)
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: subclass.new("500"))).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "rejects String subclass with invalid integer format" do
        subclass = Class.new(String)
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: subclass.new("abc"))).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end

      it "accepts frozen String subclass input" do
        subclass = Class.new(String)
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: subclass.new("500").freeze)).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end
    end

    context "custom object tests" do
      it "accepts object with #to_s returning valid integer format" do
        obj = Object.new
        def obj.to_s; "500"; end
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: obj)).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "rejects object with #to_s returning invalid integer format" do
        obj = Object.new
        def obj.to_s; "abc"; end
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: obj)).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end

      it "preserves entity identity (value not mutated)" do
        obj = Object.new
        def obj.to_s; "500"; end
        entity = { amount: obj }
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        validator.valid?(entity)
        expect(entity[:amount]).to be(obj)
      end
    end

    context "nil and condition tests" do
      it "skips validation for nil values" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: nil)).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "skips validation when :if condition returns false" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { if: proc { false } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "skips validation when :unless condition returns true" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { unless: proc { true } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(true)
        expect(validator.errors.on(:amount)).to be_nil
      end

      it "validates when :if condition returns true" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { if: proc { true } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end

      it "validates when :unless condition returns false" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: { unless: proc { false } }
        end.new
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.errors.on(:amount)).to eq(["is not an integer"])
      end
    end

    context "reuse tests" do
      it "can be reused across multiple valid? calls" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        expect(validator.valid?(amount: 5)).to be(true)
        expect(validator.valid?(amount: "abc")).to be(false)
        expect(validator.valid?(amount: 10)).to be(true)
        expect(validator.valid?(amount: "xyz")).to be(false)
      end

      it "can be reused across multiple entities" do
        validator = Class.new do
          include PoroValidator.validator
          validates :amount, integer: true
        end.new
        entity1 = { amount: 5 }
        entity2 = { amount: "abc" }
        entity3 = { amount: 10 }
        expect(validator.valid?(entity1)).to be(true)
        expect(validator.valid?(entity2)).to be(false)
        expect(validator.valid?(entity3)).to be(true)
      end
    end
  end
end
