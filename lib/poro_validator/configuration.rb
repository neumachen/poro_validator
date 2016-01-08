module PoroValidator
  class Configuration
    class Message
      # @private_const
      DEFAULT_MESSAGES = {
        default:  lambda { "is not valid" },
        presence: lambda { "is not present" },
        integer:  lambda { "is not an integer" },
        float:    lambda { "is not a float" },

        inclusion: lambda do |range|
          "is not within the range of #{range.inspect}"
        end,

        format: lambda do |pattern|
          "does not match the pattern: #{pattern.inspect}"
        end,

        length: lambda do |length|
          "does not match the length options: #{length.inspect}"
        end
      }

      def initialize
        @messages = {}
      end

      def get(validator, *args)
        args.compact.length > 0 ? message(validator).call(*args) : message(validator).call
      end

      def set(validator, message)
        unless message.is_a?(::Proc)
          raise PoroValidator::ConfigError.new(
            "A proc/lambda is required to configure validator messages"
          )
        end
        @messages[validator] = message
      end

      private

      def message(validator)
        @messages[validator] || DEFAULT_MESSAGES[validator] ||
          DEFAULT_MESSAGES[:default]
      end
    end

    attr_reader :message

    def initialize
      @message = Message.new
    end
  end
end
