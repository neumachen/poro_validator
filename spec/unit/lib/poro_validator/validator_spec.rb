require 'spec_helper'

RSpec.describe PoroValidator::Validator do
  describe "#validates" do
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
