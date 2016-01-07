module PoroValidator
  module Validators
    class FloatValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :float)
        on = options.fetch(:on, attribute)

        begin
          Kernel.Float(value.to_s)
          nil
        rescue
          errors.add(on, message)
        end
      end
    end
  end
end

