module PoroValidator
  module Validators
    class InclusionValidator < BaseClass
      def validate(attribute, value, options)
        range = options.fetch(:in)
        inclusion_method = range.respond_to?(:cover?) ? :cover? : :include?
        message = options.fetch(:message, :inclusion)

        unless range.send(inclusion_method, value)
          errors.add(attribute, message, range)
        end
      end
    end
  end
end
