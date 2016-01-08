module PoroValidator
  module Validators
    class FormatValidator < BaseClass
      def validate(attribute, value, options)
        return if value.nil?

        pattern = options.fetch(:with)
        message = options.fetch(:message, :format)

        unless value.to_s =~ pattern
          errors.add(attribute, message, pattern)
        end
      end
    end
  end
end
