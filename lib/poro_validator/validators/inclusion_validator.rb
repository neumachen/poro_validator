module PoroValidator
  module Validators
    class InclusionValidator < BaseClass
      def validate(attribute, value, options)
        range = options.fetch(:in)
        inclusion_method = range.respond_to?(:cover?) ? :cover? : :include?
        message = options.fetch(:message, :inclusion)
        on = options.fetch(:on, attribute)

        unless range.send(inclusion_method, value)
          errors.add(on, message, range)
        end
      end
    end
  end
end
