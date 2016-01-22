module PoroValidator
  module Validators
    class WithValidator < BaseClass
      def validate(attribute, value, options)
        validator_class = options.fetch(:with)
        case validator_class
        when Class
          klass = validator_class.new

          if context.entity.is_a?(::Hash)
            entity = context.entity[attribute]

            if entity.nil? || entity.is_a?(::Symbol) || entity.is_a?(::String)
              klass.valid?(attribute => entity)
            else
              klass.valid?(context.entity[attribute] || {})
            end
          else
            entity = context.entity.public_send(attribute)
            if entity.nil? || entity.is_a?(::Symbol) || entity.is_a?(::String)
              klass.valid?(attribute => entity)
            else
              klass.valid?(entity)
            end
          end

          klass.errors.public_send(:store).data.each do |k,v|
            if k.to_s == attribute.to_s
              errors.add(attribute, v.pop)
            else
              errors.add([attribute, k.to_sym], v.pop)
            end
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
