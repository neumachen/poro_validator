module PoroValidator
  module Validators
    class PresenceValidator < BaseClass
      BLANK_STRING_MATCHER = /\A[[:space:]]*\z/.freeze

      def validate(attribute, value, options)
        allow_blank = options.fetch(:allow_blank, false)
        message = options.fetch(:message, :presence)

        if value.is_a?(::String)
          if value.gsub(/\s+/, '').match(BLANK_STRING_MATCHER)
            errors.add(attribute, message) unless allow_blank
            return
          end
        end

        if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          errors.add(attribute, message)
        end
      end
    end
  end
end
