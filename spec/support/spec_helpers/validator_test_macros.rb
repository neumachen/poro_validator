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
            expect(validator.errors.count).to eq(0),
              expected_message = [
                "expected: 0 errors",
                "  actual: #{validator.errors.count} errors",
                "  object: #{validator.errors.inspect}"
              ].join("\n")
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
            expect(validator.errors.count).to be > 0,
              expected_message = [
                "expected: 0 errors",
                "  actual: #{validator.errors.count} errors",
                "  object: #{validator.errors.inspect}"
              ].join("\n")
          end

          it "sets the errors for the given attributes" do
            validator.valid?(entity)

            expected_errors.each do |key, value|
              expect(validator.errors.on(key)).to_not be_nil,
                expected_message = [
                  "expected: #{key} to have an error",
                  "  actual: #{validator.errors.on(key).inspect}",
                ].join("\n")
            end

            validator.errors.store.data.each do |attr, value|
              expect(expected_errors[attr]).to_not be_nil,
                expected_message = [
                  "expected: #{attr} to have no errors",
                  "  actual: #{validator.errors.on(attr).inspect}",
                ].join("\n")
              expect(expected_errors[attr]).to eq(value),
                expected_message = [
                  "expected: #{expected_errors[attr]}",
                  "  actual: #{validator.errors.on(attr).inspect}",
                ].join("\n")
            end
          end
        end

        example_group.class_eval(&block) if block_given?
      end

      def skip_attr_unmet_condition(&block)
        example_group = context("validation's condition unment", caller: caller) do
          let(:attr) { raise "You must override the let(:attr)!" }

          it "does not validate the attribute" do
            unless entity.is_a?(::Hash)
              expect(entity).to respond_to(attr)
            end
            validator.valid?(entity)
            expect(validator.errors.on(attr)).to be_nil,
              expected_message = [
                "expected: no errors for #{attr}",
                "  actual: #{validator.errors.on(attr).inspect}",
              ].join("\n")
          end
        end

        example_group.class_eval(&block) if block_given?
      end
    end
  end
end
