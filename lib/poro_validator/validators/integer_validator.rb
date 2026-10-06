module PoroValidator
  module Validators
    class IntegerValidator < NumericValidator
      NUMERIC_OPTIONS = [:extremum, :max, :min, :in].freeze

      def validate(attribute, value, options)
        return if value.nil?

        validate_numeric_options(options.keys)

        if is_numeric?(value.to_s, INTEGER_MATCHER)
          return nil
        end

        message = options[:message] || :integer
        errors.add(attribute, message)
      end

      private

      def validate_numeric_options(options_keys)
        offending = options_keys & NUMERIC_OPTIONS
        return if offending.empty?

        raise ::PoroValidator::InvalidValidator.new(
          "IntegerValidator does not support numeric options: #{offending.inspect}"
        )
      end
    end
  end
end
