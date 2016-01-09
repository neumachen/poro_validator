module PoroValidator
  module Validators
    class RangeArrayValidator < BaseClass
      def validate_option(option)
        !option.nil? && (option.is_a?(::Range) || option.is_a?(::Array))
      end

      def covered?(range, value)
        return unless range.respond_to?(:cover?)
        range.cover?(value)
      end

      def included?(array, value)
        return unless array.respond_to?(:include?)
        array.include?(value)
      end
    end
  end
end
