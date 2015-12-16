module PoroValidator
  module Validator
    class Factory
      class Validators
        class << self
          def set_validator(attr_name, validator, options={})
            klass = class_name(validator)
            begin
              PoroValidator.const_get(klass).new(attr_name, options)
            rescue NameError => e
              raise(::PoroValidator::ValidatorNotFound.new(
                "Validator not found: ::PoroValidator::#{klass} exception: #{e}"
              ))
            end
          end

          private

          def class_name(validator)
            "Validators::#{camel_case(validator.to_s)}Validator"
          end

          def camel_case(str)
            str.split('_').map do |char|
              char.capitalize
            end.join('')
          end
        end
      end
    end
  end
end
