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

      def build(attr, **options)
        @validators = options.reject do |k,v|
          [:if, :unless].include?(k)
        end

        @conditions = [] << options.select do |k,v|
          [:if, :unless].include?(k)
        end

        @validators.each do |validator,options|
          nested_conditions = {}
          if options.is_a?(::Hash)
            # Check if there are any nested conditions for a validator
            # options and select if it exists.
            #
            # e.g
            #   validates :foo, format: { with: "hello", unless: :foo_rule }
            nested_conditions = options.select do |k,v|
              [:if, :unless].include?(k)
            end

            # Remove the nested conditions from the validator options.
            unless nested_conditions.empty?
              options.reject! { |k,v| [:if, :unless].include?(k) }
              @conditions << nested_conditions
            end
          end

          self << { validator: Validation.build(attr, validator, options),
                    conditions: @conditions.reject(&:empty?)
          }
        end
      end
    end
  end
end
