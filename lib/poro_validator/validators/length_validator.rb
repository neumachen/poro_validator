module PoroValidator
  module Validators
    class LengthValidator < BaseClass
      def validate(attribute, value, options)
        message = options.fetch(:message, :length)

        options.keys.each do |key|
          matcher = matchers(key)
          next if matcher.nil?
          v = value.is_a?(::String) ? value : value.to_s
          unless matchers(key).call(v, options[key])
            errors.add(attribute, message, key => options[key])
          end
        end
      end

      private

      def matchers(key)
        m = {
          extremum: lambda do |value, length|
            value.length == length
          end,

          max: lambda do |value, length|
            value.length <= length
          end,

          min: lambda do |value, length|
            value.length >= length
          end,

          in: lambda do |value, length|
            length.cover?(value.length)
          end
        }
        m.fetch(key, nil)
      end
    end
  end
end
