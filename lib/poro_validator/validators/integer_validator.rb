module PoroValidator
  module Validators
    class IntegerValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :integer)

        begin
          Kernel.Integer(value.to_s)
          nil
        rescue
          errors.add(attribute, message)
        end
      end

    end
  end
end
