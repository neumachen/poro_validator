module PoroValidator
  module Validators
    class ExclusionValidator < BaseClass
      def validate(attribute, value, options)
        range = options.fetch(:in, nil)

        if range.nil?
          raise ::PoroValidator::InvalidValidator,
            [
              "There was no range or array specified. Pass in a range or array.",
              "e.g",
              "validates :foo, exclusion: 1..10",
              "or",
              "validates :boo, exclusion: { in: 1..10 }"
          ].join("\n")
        end

        unless range.is_a?(::Range) || range.is_a?(::Array)
          raise ::PoroValidator::InvalidValidator,
            [
              "There was no range or array specified. Pass in a range or array.",
              "e.g",
              "validates :foo, exclusion: 1..10",
              "or",
              "validates :boo, exclusion: { in: 1..10 }"
          ].join("\n")
        end

        message = options.fetch(:message, :exclusion)

        if range.respond_to?(:cover?)
          if range.cover?(value)
            errors.add(attribute, message, range)
            return
          end
        end

        if range.respond_to?(:include?)
          if range.include?(value)
            errors.add(attribute, message, range)
            return
          end
        end
      end
    end
  end
end
