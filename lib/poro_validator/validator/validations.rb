module PoroValidator
  module Validator
    # @private
    class Validations < BaseClass
      def self.build_validations(validations = [])
        inst = new
        unless validations.empty?
          validations.each do |validation|
            inst << validation
          end
        end
        inst
      end

      def initialize(&block)
        super()
        instance_eval(&block) if block_given?
      end

      # Conditions given to `validates` itself apply to every validator in the
      # declaration; conditions inside one validator's options apply to that
      # validator only.
      def build(attr, **options)
        declaration_conditions = options.select do |k,v|
          [:if, :unless].include?(k)
        end

        @validators = {}
        options.each do |validator,validator_options|
          next if [:if, :unless].include?(validator)

          conditions = [declaration_conditions]
          if validator_options.is_a?(::Hash)
            # Check if there are any nested conditions for a validator
            # options and select if it exists.
            #
            # e.g
            #   validates :foo, format: { with: "hello", unless: :foo_rule }
            nested_conditions = validator_options.select do |k,v|
              [:if, :unless].include?(k)
            end

            # Pass the validator its options without the nested conditions,
            # in a shallow copy: the caller's Hash may be frozen or reused.
            # #dup keeps the Hash's class, instance variables and default
            # value or Proc, which a filtering method like #reject would drop.
            unless nested_conditions.empty?
              validator_options = validator_options.dup
              validator_options.delete(:if)
              validator_options.delete(:unless)
              conditions << nested_conditions
            end
          end

          @validators[validator] = validator_options
          self << { validator: Validation.build(attr, validator, validator_options),
                    conditions: conditions.reject(&:empty?)
          }
        end
      end
    end
  end
end
