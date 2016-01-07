module SpecHelpers
  module ValidatorTestMacros
    extend SpecHelpers::Concerns

    included do
      let(:entity)          { raise "You must override the let(:entity)" }
      let(:expected_errors) { raise "You must override let(:expected_errors)" }

      subject(:validator) do
        raise "You must override the subject(:validator)"
      end
    end

    module ClassMethods
      def expect_validator_to_be_valid(&block)
        example_group = context("valid entity", caller: caller) do
          it "returns false for #valid?" do
            expect(validator.valid?(entity)).to be_truthy
          end

          it "returns a count of 0 for #errors.count" do
            validator.valid?(entity)
            expect(validator.errors.count).to eq(0)
          end
        end

        example_group.class_eval(&block) if block_given?
      end

      def expect_validator_to_be_invalid(&block)
        example_group = context("invalid entity", caller: caller) do
          it "returns false for #valid?" do
            expect(validator.valid?(entity)).to be_falsey
          end

          it "returns a count greater than 0 for #errors.count" do
            validator.valid?(entity)
            expect(validator.errors.count).to be > 0
          end

          it "sets the errors for the given attributes" do
            validator.valid?(entity)
            validator.errors.store.data.each do |attr, value|
              expect(expected_errors[attr]).to_not be_nil,
                "no expected_errors for #{attr}"
              expect(expected_errors[attr]).to eq(value),
                "expected_errors[#{attr}] did not match #{value}"
            end
          end
        end

        example_group.class_eval(&block) if block_given?
      end

      def skip_attr_unmet_condition(&block)
        example_group = context("validation's condition unment", caller: caller) do
          let(:attr) { raise "You must override the let(:attr)!" }

          it "expects that attribute is not valid" do
            validations = \
              validator.class.validations.validations.inject({}) do |r, validation|
              r[validation[:validator].attribute] = validation[:validator].options
              r
            end

            expect(entity.public_send(attr)).to_not match(/[0-9]/)
          end

          it "does not validate the attribute: dob" do
            validator.valid?(entity)
            expect(validator.errors.on(:dob)).to be_nil
          end
        end

        example_group.class_eval(&block) if block_given?
      end
    end
  end
end
