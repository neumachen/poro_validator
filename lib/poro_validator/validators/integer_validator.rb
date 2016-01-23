module PoroValidator
  module Validators
    class IntegerValidator < NumericValidator
      def validate(attribute, value, options)
        if is_numeric?(value.to_s, INTEGER_MATCHER)
          return nil
        end

        message = options[:message] || :integer
        errors.add(attribute, message)
      end

    end
  end
end
