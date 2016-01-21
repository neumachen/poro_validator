module PoroValidator
  module Validator
    class Validation
      # Builds a validation from the params passed which is initiated first
      # then passed into the Validators.set_validator method
      #
      # @params[attr_name] - name of the attribute to be validated
      # @params[validator] - validator class to be used for validating
      # attribute
      # @params[options]   - arguments against validator and additional options
      #   e.g, message:, on:, etc.
      def self.build(attr_name, validator, options)
        b = new(attr_name, validator, options)
        b = Factory::Validators.set_validator(
          b.attr_name,
          b.validator,
          b.options
        )
        b
      end

      def initialize(attr_name, validator, options = nil)
        @attr_name = attr_name
        @validator = validator
        opts =
          case options
          when TrueClass
            {}
          when Hash
            options
          when Range, Array
            { in: options }
          else
            { with: options }
          end
        @options = opts
      end

      def options
        @options
      end

      def attr_name
        @attr_name
      end

      def validator
        @validator
      end
    end
  end
end
