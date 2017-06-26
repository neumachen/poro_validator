module PoroValidator
  module Validator
    class BaseClass
      # Public - Initializes the base class that creates a default value for
      # the @validations variable with an empty array
      #
      # @validations - Stores all the validations intended for a Ruby object
      #   (entity)
      def initialize
        @validations = []
      end

      # Public - Calls the internal #validate method to perform the
      # validations stored in the @validations instance array against a
      # validator context if the conditions are truthy.
      def run_validations(context)
        validate(context)
      end

      # Adds/appends validations to the validations array
      #
      # @params[validation] - Validator Object to be stored to the array of
      # validations.
      def <<(validation)
        @validations << validation
      end

      # @return array of hashes of validations and conditions
      def validations
        @validations
      end

      # @return array of validators
      def validators
        @validators
      end

      private

      # @private
      def validate(context)
        validations.each do |validation|
          conditions = validation[:conditions] || {}

          unless conditions.empty?
            next unless Conditions.matched?(conditions, context)
          end

          validation[:validator].validate_context(context)
        end
      end
    end
  end
end
