require 'spec_helper'

RSpec.describe "Compose validations using existing validations", type: :feature do
  context "an existing validator already exists" do
    AddressEntityValidator = Class.new do
      include PoroValidator.validator

      validates :line1,    presence: true
      validates :line2,    presence: true
      validates :city,     presence: true
      validates :state,    presence: true
      validates :zip_code, presence: true
    end

    it "uses the existing validator as for the validation" do
      CustomerDetailEntityValidation = Class.new do
        include PoroValidator.validator

        validates :address, with: AddressEntityValidator
      end

      expect(CustomerDetailEntityValidation.validations.validators).
        to eq({with: AddressEntityValidator})
    end
  end
end
