module PoroValidator
  module Validators
    class WithValidator < BaseClass

      def validate(attribute, value, options)
        klass = options.fetch(:with)
        case klass
        when Class
          k = klass.new
          k.valid?(context.entity.send(attribute))
          k.errors.send(:store).data.each do |k,v|
            errors.add(attribute, [k, v])
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
