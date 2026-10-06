module PoroValidator
  module Validator
    class Conditions
      def self.matched?(conditions, context)
        results = []
        inst    = new(context)

        conditions.each do |condition|
          condition.each do |type, value|
            unless [:if, :unless].include?(type)
              raise ::PoroValidator::InvalidCondition.new(
                "Unimplemented conditional key: #{type}"
              )
            end

            if value.is_a?(::Array)
              value.each do |v|
                results << inst.match_condition(type, v)
              end
              next
            end

            results << inst.match_condition(type, value)
            next
          end
        end

        # Every condition has been evaluated. As in Ruby, a nil or false result
        # fails its condition and any other result passes it.
        results.all?
      end

      def initialize(context)
        @context = context
      end

      def match_condition(type, condition)
        result =
          case condition
          when String
            condition_type[String].call(context, condition)
          when Symbol
            condition_type[Symbol].call(context, condition)
          when Proc
            # A lambda without parameters can't take the context. Every other
            # Proc or lambda gets it, including a Proc whose only parameter is
            # optional, although its arity is 0 too.
            if condition.lambda? && condition.arity.zero?
              condition.call
            else
              condition.call(context)
            end
          else
            raise ::PoroValidator::InvalidCondition.new(
              "Unimplemented condition: #{condition.inspect}"
            )
          end

        if type == :unless
          return !result
        end
        result
      end

      private

      def context
        @context
      end

      def condition_type
        {
          String => lambda { |context, string| context.entity.instance_eval(string) },
          Symbol => lambda { |context, method| context.context.send(method, context.entity) },
        }
      end
    end
  end
end
