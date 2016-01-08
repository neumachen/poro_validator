module PoroValidator
  module Validators
    class NumericValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :numeric)

        begin
          Kernel.Integer(value.to_s)
          nil
        rescue
          errors.add(attribute, :integer)
          return
        end

        options.keys.each do |key|
          matcher = matchers(key)
          next if matcher.nil?
          unless matchers(key).call(value, options[key])
            errors.add(attribute, message, key => options[key])
          end
        end
      end

      private

      def matchers(key)
        m = {
          extremum: lambda do |value, length|
            value == length
          end,

          max: lambda do |value, length|
            value <= length
          end,

          min: lambda do |value, length|
            value >= length
          end,

          in: lambda do |value, length|
            length.cover?(value)
          end
        }
        m.fetch(key, nil)
      end
    end
  end
end
