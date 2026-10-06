module PoroValidator
  module Validators
    class BaseClass
      # A rule is created once per `validates` declaration and shared by every
      # instance of the validator class and of its subclasses. So the context
      # of a call in progress, which holds its entity and errors, is kept per
      # fiber, in a stack for each rule, rather than only in the rule's
      # instance variables: another call cannot replace it, and a call nested
      # inside it on the same fiber unwinds back to it.
      CALLS_IN_PROGRESS = :__poro_validator_calls_in_progress__
      private_constant :CALLS_IN_PROGRESS

      attr_writer :attribute

      def initialize(attribute, options = {})
        @attribute = attribute
        @options   = options
      end

      def options
        @options
      end

      def attribute
        @attribute
      end

      # The errors and context of this rule's call in progress on the current
      # fiber. Anywhere else, such as in a thread or fiber started by
      # #validate, they are the most recent call's, as before.
      def errors
        (current = __current_context__) ? current.errors : @errors
      end

      def context
        __current_context__ || @context
      end

      def nested?
        attribute.is_a?(::Array)
      end

      def validate(attribute, value, options)
        raise ::PoroValidator::OverloadriddenRequired.new(
          "This method needs to be overloaded/overriden."
        )
      end

      def value
        if entity_is_hash = context.entity.is_a?(::Hash)
          context.entity.extend(::PoroValidator::Utils::DeepFetch)
        end

        if nested?
          if entity_is_hash
            @value = context.entity.deep_fetch(*attribute.flatten) do
              nil
            end
          else
            @value = attribute.flatten.inject(context.entity, :public_send)
          end
        else
          if entity_is_hash
            @value = context.entity.deep_fetch(attribute) do
              nil
            end
          else
            @value = context.entity.public_send(attribute)
          end
        end
      end

      # @private
      def __validate__(validator_context)
        @context = validator_context
        @errors  = validator_context.errors
        calls = (Thread.current[CALLS_IN_PROGRESS] ||= {}.compare_by_identity)
        (calls[self] ||= []).push(validator_context)
        begin
          validate(attribute, value, options)
        ensure
          contexts = calls[self]
          contexts.pop
          calls.delete(self) if contexts.empty?
          Thread.current[CALLS_IN_PROGRESS] = nil if calls.empty?
        end
      end

      private

      # @private
      def __current_context__
        calls = Thread.current[CALLS_IN_PROGRESS]
        contexts = calls && calls[self]
        contexts && contexts.last
      end
    end
  end
end
