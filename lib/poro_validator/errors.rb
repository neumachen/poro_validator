module PoroValidator
  class Errors

    attr_reader :store

    def initialize
      @store = ErrorStore.new
    end

    def add(attr, msg, *msg_opts)
      if store.set?(attr)
        store.get(attr) << message_lookup(msg, *msg_opts)
      else
        store.set(attr, [message_lookup(msg, *msg_opts)])
      end
    end

    def count
      store.data.inject(0) do |m, kv|
        _, errors = *kv
        m + errors.length
      end
    end

    def empty?
      count == 0
    end

    def full_messages
      store.data.inject([]) do |m, kv|
        attr, errors = *kv
        errors.each { |e| m << "#{attr} #{e}" }
        m
      end
    end

    def on(attr)
      return unless store.set?(attr)
      store.get(attr)
    end

    def clear_errors
      store.reset
    end

    alias_method :[], :on

    private

    def message_lookup(msg, *msg_opts)
      msg.is_a?(Symbol) ? ::PoroValidator.configuration.message.get(msg, *msg_opts) : msg
    end
  end
end
