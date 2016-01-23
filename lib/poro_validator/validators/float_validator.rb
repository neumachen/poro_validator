module PoroValidator
  module Validators
    class FloatValidator < NumericValidator
      def validate(attribute, value, options)
        if is_numeric?(value.to_s, FLOAT_MATCHER)
          return
        end

        message = options[:message] || :float
        errors.add(attribute, message)
      end
    end
  end
end
