module PoroValidator
  module Validators
    class NumericValidator < BaseClass
      INTEGER_MATCHER = /\A[-+]?(\d+|\d{1,3}(,\d{3})*)\z/.freeze
      FLOAT_MATCHER   = /\A[-+]?(\d+|\d{1,3}(,\d{3})*)(\.\d+)\z/.freeze

      VALID_OPTIONS = [
        :extremum, :max, :min, :in
      ].freeze

      VALID_OPTION_VALUES = [
        ::Range, ::Array, ::Fixnum, ::Numeric
      ].freeze

      def validate(attribute, value, options)
        return if value.nil?

        unless is_numeric?(value.to_s, INTEGER_MATCHER) ||
            is_numeric?(value.to_s, FLOAT_MATCHER)
          errors.add(attribute, :integer_or_float)
          return
        end

        message = options[:message] || :numeric

        validate_numeric_options(options.keys)

        options.each do |k, v|
          unless VALID_OPTION_VALUES.include?(v.class)
            raise ::PoroValidator::InvalidValidator.new(
              "Invalid option: #{k} => #{v}"
            )
          end

          unless matchers(k).call(value, v)
            errors.add(attribute, message, k => v)
          end
        end
      end

      private

      def validate_numeric_options(options_keys)
        opts = options_keys - VALID_OPTIONS

        return if opts.length <= 0

        unless VALID_OPTIONS.include?(opts)
          raise ::PoroValidator::InvalidValidator.new(
            "Invalid options: #{opts.inspect} passed for numeric validator."
          )
        end
      end

      def matchers(key)
        {
          extremum: proc do |value, length|
            value == length
          end,

          max: proc do |value, length|
            value <= length
          end,

          min: proc do |value, length|
            value >= length
          end,

          in: proc do |value, length|
            length.cover?(value)
          end
        }[key] || nil
      end

      def is_numeric?(v, regex_match)
        v =~ regex_match
      end
    end
  end
end
