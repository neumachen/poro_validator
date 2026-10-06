module PoroValidator
  class Errors

    attr_reader :store

    def initialize
      @store = ErrorStore.new
    end

    def add(attr, validator, *msg_opts)
      if store.set?(attr)
        target = store
        messages = target.get(attr)
        # Only an ErrorStore keeps path records; any other store gets the
        # plain append.
        if ErrorStore === target
          target.__append__(attr, messages) { message_lookup(validator, *msg_opts) }
        else
          messages << message_lookup(validator, *msg_opts)
        end
      else
        store.set(attr, [message_lookup(validator, *msg_opts)])
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
      self.store.reset
    end

    alias_method :[], :on

    private

    def message_lookup(validator, *msg_opts)
      validator.is_a?(Symbol) ? ::PoroValidator.configuration.message.get(
        validator, *msg_opts
      ) : validator
    end
  end
end
