module SpecHelpers
  module ValidatorTestMacros
    extend SpecHelpers::Concerns

    included do
      let(:attribute)       { raise "You must override attribute" }
      let(:validation)      { raise "You must override validator" }
      let(:conditions)      { raise "You must override conditions" }
      let(:attribute_value) { raise "You must override valid_value" }
      let(:expected_error)  { raise "You must override expected_error" }
    end

    module ClassMethods
      def expects_to_pass_validation(&block)
        it "does not assign an error to the attribute" do
          # without calling the let variable attribute or any of within the
          # included do block, it returns undefined method. But calling the
          # let variable attribute and assigning it to another variable works.
          # It must have something todo with scoping.
          attr    = attribute
          options = validation.merge(conditions)

          value   = attribute_value

          validator = Class.new do
            include PoroValidator.validator

            validates attr, options
          end.new

          entity = OpenStruct.new(attribute => value)

          expect(validator.valid?(entity)).to be_truthy
          expect(validator.errors[attr]).to eq(expected_error)
        end
      end

      def expects_to_fail_validation(&block)
        it "assigns an error to the attribute" do
          attr    = attribute
          options = validation.merge(conditions)

          value   = attribute_value

          validator = Class.new do
            include PoroValidator.validator

            validates attr, options
          end.new

          entity = OpenStruct.new(attribute => value)

          expect(validator.valid?(entity)).to be_falsey
          expect(validator.errors[attr]).to eq(expected_error)
        end
      end

      def expects_to_raise_error
        it "raises an error" do
          attr    = attribute
          options = validation.merge(conditions)

          value   = attribute_value

          validator = Class.new do
            include PoroValidator.validator

            validates attr, options
          end.new

          entity = OpenStruct.new(attribute => value)

          expect { validator.valid?(entity) }.to raise_error
        end

      end
    end
  end
end
