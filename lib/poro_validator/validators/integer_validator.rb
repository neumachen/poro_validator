module PoroValidator
  module Validators
    class IntegerValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :integer)
        on = options.fetch(:on, attribute)

        begin
          Kernel.Integer(value.to_s)
          nil
        rescue
          errors.add(on, message)
        end
      end

    end
  end
end
