require 'spec_helper'

RSpec.describe PoroValidator::Validators::FormatValidator do
  describe "#validate" do
    context "if the attribute is not present" do
      context "and it passes the condition" do
        it "assigns the attribute error" do
          validator = Class.new do
            include PoroValidator.validator
            validates :name, format: /[a-z]/, if: proc { true }
          end.new

          entity = Class.new do
            attr_accessor :name
          end.new

          entity.name = "0000"

          validator.valid?(entity)
          expect(validator.errors[:name]).to_not be_empty
          expect(validator.errors[:name]).to eq(["does not match the pattern: /[a-z]/"])
        end
      end
    end

    context "if the attribute is present" do
      it "does not assign an attribute error" do
        validator = Class.new do
          include PoroValidator.validator

          validates :name, presence: true
        end.new

        entity = Class.new do
          attr_accessor :name
        end.new

        entity.name = "manbearpig"

        validator.valid?(entity)
        expect(validator.errors[:name]).to be_nil
      end
    end
  end
end
