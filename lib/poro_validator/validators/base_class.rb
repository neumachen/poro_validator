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
        @errors ||= context.errors
      end

      def context
        @context
      end

      def validate(attribute, value, options)
        raise ::PoroValidator::OverloadriddenRequired.new(
          "This method needs to be overloaded/overriden."
        )
      end

      # @private
      def __validate__(validator_context)
        @context = validator_context
        @errors  = context.errors
        value    = context.entity.public_send(attribute)
        validate(attribute, value, options)
      end
    end
  end
end
