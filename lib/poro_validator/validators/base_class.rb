module PoroValidator
  module Validators
    class BaseClass
      attr_writer :attribute

      def initialize(attribute, options = {})
        @attribute = attribute
        @options   = options
      end

      def options
        @options
      end

      def attribute
        @attribute
      end

      def errors
        @errors
      end

      def context
        @context
      end

      def nested?
        attribute.is_a?(::Array)
      end

      def validate(attribute, value, options)
        raise ::PoroValidator::OverloadriddenRequired.new(
          "This method needs to be overloaded/overriden."
        )
      end

      def value
        if entity_is_hash = context.entity.is_a?(::Hash)
          context.entity.extend(::PoroValidator::Utils::DeepFetch)
        end

        if nested?
          if entity_is_hash
            @value = context.entity.deep_fetch(*attribute.flatten) do
              nil
            end
          else
            @value = attribute.flatten.inject(context.entity, :public_send)
          end
        else
          if entity_is_hash
            @value = context.entity.deep_fetch(attribute) do
              nil
            end
          else
            @value = context.entity.public_send(attribute)
          end
        end
      end

      # @private
      def validate_context(validator_context)
        @context = validator_context
        @errors  = validator_context.errors
        validate(attribute, value, options)
      end
    end
  end
end
