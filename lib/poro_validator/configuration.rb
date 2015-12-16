module PoroValidator
  class Configuration
    class Message
      # @private_const
      DEFAULT_MESSAGES = {
        default:  lambda { "is not valid" },
        format:   lambda { |pattern| "does not match the pattern: #{pattern.inspect}"},
        presence: lambda { "is not present" }
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
