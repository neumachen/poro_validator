module PoroValidator
  module Validators
    class WithValidator < BaseClass
      def validate(attribute, value, options)
        validator_class = options.fetch(:with)
        case validator_class
        when Class
          klass = validator_class.new
          klass.valid?(context.entity.public_send(attribute))
          klass.errors.public_send(:store).data.each do |k,v|
            errors.add([attribute, k.to_sym], v.pop)
          end
        else
          raise ::PoroValidator::InvalidValidator.new(
            "Requires a class object for this validator."
          )
        end
      end
    end
  end
end
