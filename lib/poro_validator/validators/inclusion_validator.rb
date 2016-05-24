module PoroValidator
  module Validators
    class InclusionValidator < RangeArrayValidator
      def validate(attribute, value, options)
        return if value.nil?

        in_option = options[:in]

        unless validate_option(in_option)
          raise ::PoroValidator::InvalidValidator,
            [
              "There was no range or array specified. Pass in a range or array.",
              "e.g",
              "validates :foo, inclusion: 1..10",
              "or",
              "validates :boo, inclusion: { in: 1..10 }"
          ].join("\n")
        end

        message = options.fetch(:message, :inclusion)

        unless covered?(in_option, value) || included?(in_option, value)
          errors.add(attribute, message, in_option)
        end
      end
    end
  end
end
