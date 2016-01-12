require 'spec_helper'

RSpec.describe "validates hash object", type: :feature do
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

    context "if validation fails" do
      let(:validator) { subject.new }

      let(:invalid_entity) do
        {
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
                latitude: nil,
                planet: {
                  name: nil
                }
              }
            }
          }
        }
      end

      it "validates a hash object" do
        expect(invalid_entity).to be_kind_of(::Hash)
      end

      describe "#valid?" do
        it "returns false" do
          expect(validator.valid?(invalid_entity)).to be_falsey
        end

        context "empty hash" do
          let(:invalid_entity) { {} }

          it "validates an empty hash" do
            expect(invalid_entity).to be_empty
          end

          it "returns false" do
            expect(validator.valid?({})).to be_falsey
          end
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
