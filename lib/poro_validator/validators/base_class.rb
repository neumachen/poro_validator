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
        @errors ||= context.errors
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
        if nested?
          @value = attribute.flatten.inject(context.entity, :public_send)
        else
          @value = context.entity.public_send(attribute)
        end
      end

      # @private
      def __validate__(validator_context)
        @context = validator_context
        @errors  = context.errors
        validate(attribute, value, options)
      end
    end
  end
end
