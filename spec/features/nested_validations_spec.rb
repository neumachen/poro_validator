require 'spec_helper'
require 'recursive-open-struct'

RSpec.describe "Allows nested validations to be setup", type: :feature do
  context "allows nested structure validations" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :customer_id, presence: true

        validates :customer do
          validates :first_name, presence: true
          validates :last_name,  presence: true
        end

        validates :address do
          validates :line1, presence: true
          validates :line2, presence: true
          validates :city,  presence: true
          validates :country do
            validates :iso_code,   presence: true
            validates :short_name, presence: true
            validates :coordinates do
              validates :longtitude, presence: true
              validates :latitude,   presence:true
              validates :planet do
                validates :name, presence: true
              end
            end
          end
        end
      end
    end

    it "creates validatons for the nested structure" do
      expected_validations = [
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: :customer_id
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:customer, :first_name]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:customer, :last_name]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, :line1]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, :line2]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, :city]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, [:country, :iso_code]]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, [:country, :short_name]]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, [:country, [:coordinates, :longtitude]]]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, [:country, [:coordinates, :latitude]]]
        },
        {
          validator: PoroValidator::Validators::PresenceValidator,
          attribute: [:address, [:country, [:coordinates, [:planet, :name]]]]
        }
      ]

      actual_validations = \
        validator.validations.validations.inject([]) do |result, value|
          result << { validator: value[:validator].class,
                      attribute: value[:validator].attribute
          }
      end

      expect(actual_validations).to eq(expected_validations)
    end

    context "if validation fails" do
      let(:validator) { subject.new }

      let(:invalid_entity) do
        RecursiveOpenStruct.new(
          customer: {
            first_name: "Man Bear",
            last_name: nil,
          },
          address: {
            line1: "175 West Jackson Boulevard",
            line2: "5th Floor",
            city: "Chicago",
            country: {
              iso_code: "33CHIC",
              short_name: "CHICAGOUSA",
              coordinates: {
                longtitude: nil,
                latitude: nil,
                planet: {
                  name: nil
                }
              }
            }
          }
        )
      end

      describe "#valid?" do
        it "returns false" do
          expect(validator.valid?(invalid_entity)).to be_falsey
        end
      end

      describe "#errors" do
        it "returns a non empty error hash" do
          validator.valid?(invalid_entity)
          expect(validator.errors.count).to be > 0
        end
      end
    end
  end
end
