module PoroValidator
  module Validator
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def validates(attr_name, **options, &block)
        if block_given?
          nested_validations = build_nested_validations(attr_name, &block)
          nested_validations.each do |nested_validation|
            validations << nested_validation
          end
        else
          validations.build(attr_name, **options)
        end
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

      def build_nested_validations(attr_name, &block)
        nested_validator = Class.new do
          include PoroValidator.validator
        end
        nested_validator.instance_eval(&block)
        nested_validations = nested_validator.validations.validations
        nested_validations.each do |nv|
          nv[:validator].attribute = [attr_name, nv[:validator].attribute]
        end
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
      @errors
    end

    def valid?(entity)
      if entity.is_a?(::Hash)
        entity.extend(::PoroValidator::Utils::DeepSymbolizeKeys)
        entity = entity.deep_symbolize_keys
      end
      validate_entity(entity)
      errors.empty?
    end

    private

    def validate_entity(entity)
      @errors = PoroValidator::Errors.new
      context = Context.new(entity, self, @errors)
      self.class.validations.run_validations(context)
    end
  end
end
