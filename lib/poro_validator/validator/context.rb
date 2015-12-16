module PoroValidator
  module Validator
    class Context
      attr_reader :entity, :context, :errors

      # Initializes a new validator context
      #
      # @param entity [Object] The entity which to be validated
      # @param context [self] The validating/validator class
      # @param errors [Object] Error cache

      def initialize(entity, context, errors)
        @entity  = entity
        @context = context
        @errors  = errors
      end
    end
  end
end
