require 'spec_helper'

RSpec.describe "Allows a validator class to be subclassed", type: :feature do
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
      expect(validator.errors.full_messages).
        to eq(["name is not present", "customer_id is not present"])
    end
  end
end
