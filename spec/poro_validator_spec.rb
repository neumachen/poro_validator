require 'spec_helper'

RSpec.describe PoroValidator do
  it "has a version number" do
    expect(PoroValidator::VERSION).not_to be_nil
  end

  describe ".validator" do
    context "it allows access to the anonymous validator module" do
      let(:klass) do
        Class.new do
          include PoroValidator.validator
        end.new
      end

      it "has a .validates class method" do
        expect(klass.class).to respond_to(:validates)
      end

      it "has #valid? in on instance" do
        expect(klass).to respond_to(:valid?)
      end

      it "allows validations to be set" do
        obj = Class.new do
          include PoroValidator.validator

          validates :foo, presence: true
        end

        validations = obj.send(:validations)

        expect(validations.validations.count).to eq(1)
        expect(validations.validators).to eq({presence: true})
      end
    end
  end

  describe "#inherited" do
    context "if an existing validator is subclassed" do
      it "ensures that the validation rules are carried over" do
        class PersonValidator
          include PoroValidator.validator

          validates :name, presence: true
        end

        class CustomerValidator < PersonValidator
          validates :customer_id, presence: true
        end

        entity = Class.new do
          attr_accessor :customer_id
          attr_accessor :name
        end.new

        validator = CustomerValidator.new
        validator.valid?(entity)

        expect(validator.errors.count).to eq(2)
        expect(validator.errors.full_messages).to eq(["name is not present", "customer_id is not present"])
      end
    end
  end

  describe "#valid?" do
    let(:entity)    { TestHelpers::TestEntity.new }
    let(:validator) { TestHelpers::TestEntityValidator.new }

    context "if the entity is not valid" do
      it "returns false" do
        expect(validator.valid?(entity)).to be_falsey
      end

      it "returns the errors for related to the entity" do
        validator.valid?(entity)
        expect(validator.errors.full_messages).to eq(["name is not present"])
      end
    end

    context "if the entity is valid" do
      before(:each) do
        entity.name = "manbearpig"
      end

      it "returns true" do
        expect(validator.valid?(entity)).to be_truthy
      end

      it "returns an empty hash for the #errors" do
        validator.valid?(entity)
        expect(validator.errors).to be_empty
      end
    end
  end
end
