module PoroValidator
  module Validators
    class BaseClass
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

      def validate(attribute, value, options)
        raise ::PoroValidator::OverloadriddenRequired.new(
          "This method needs to be overloaded/overriden."
        )
      end

      # @private
      def __validate__(validator_context)
        @errors = validator_context.errors
        value   = validator_context.entity.public_send(attribute)
        validate(attribute, value, options)
      end
    end
  end
end
