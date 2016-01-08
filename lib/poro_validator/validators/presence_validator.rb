module PoroValidator
  module Validators
    class PresenceValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :presence)
        v = value.is_a?(String) ? value.gsub(/\s+/, '') : value

        if v.nil? || v.respond_to?(:empty?) && v.empty?
          errors.add(attribute, message)
        end
      end
    end
  end
end
