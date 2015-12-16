module PoroValidator
  module Validator
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def validates(attr_name, **options)
        validations.build(attr_name, **options)
      end

      def validations
        @validations ||= build_validations
      end


      private

      def build_validations(validations = [])
        Validations.build_validations(validations)
      end

      def validates_with(vals)
        @validations = vals
      end

      # Ensures that when a Validator class is subclassed, the
      # validation rules will be carried into the subclass as well.
      #
      # @example
      #   class PersonValidator
      #     include Veto.validator
      #     validates :name, presence: true
      #   end
      #
      #   class CustomerValidator < PersonValidator
      #     validates :customer_id, presence: true
      #   end
      #
      #   customer = Customer.new
      #   validator = CustomerValidator.new
      #   validator.validate!(customer) # => ["name is not present", "customer_id is not present"]
      def inherited(descendant)
        descendant.send(:validates_with, (build_validations(validations.validations.dup)))
      end
    end

    def errors
      @errors ||= ::PoroValidator::Errors.new
    end

    def valid?(entity)
      validate_entity(entity)
      errors.empty?
    end

    private

    def validate_entity(entity)
      errors.clear_errors
      context = Context.new(entity, self, errors)
      self.class.validations.run_validations(context)
    end
  end
end
