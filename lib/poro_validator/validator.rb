module PoroValidator
  module Validator
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def validates(attr_name, **options, &block)
        if block_given?
          nested_validations = build_nested_validations(attr_name, &block)
          propagate_block_conditions(nested_validations, options)
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

      # Prepends the block declaration's own :if/:unless to every leaf
      # validation produced by its block, ahead of that leaf's existing
      # declaration/rule-local conditions. Each leaf keeps its own groups;
      # this only adds one more group evaluated first. Non-condition keys
      # in `options` are not inspected here and remain ignored, as for any
      # other block declaration option.
      #
      # Builds a fresh Array and a fresh selected Hash rather than mutating
      # `options` (the caller's Hash, possibly frozen/reused) or the nested
      # validation's existing :conditions Array.
      def propagate_block_conditions(nested_validations, options)
        block_conditions = options.select { |k, _| [:if, :unless].include?(k) }
        return if block_conditions.empty?

        nested_validations.each do |nested_validation|
          nested_validation[:conditions] = [block_conditions] + nested_validation[:conditions]
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
