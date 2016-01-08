module PoroValidator
  module Validators
    class FloatValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :float)

        begin
          Kernel.Float(value.to_s)
          nil
        rescue
          errors.add(attribute, message)
        end
      end
    end
  end
end

