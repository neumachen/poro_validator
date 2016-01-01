module PoroValidator
  class ErrorStore
    attr_reader :data

    def initialize(data = {})
      @data = {}
      self.load(data)
    end

    def get(key)
      validate_key!(key)
      @data[key.to_s]
    end

    def set(key, value = nil, &block)
      validate_key!(key)
      if key.is_a?(::Array)
        key = key.flatten.reverse.inject do |a,n|
          { n => a }
        end
      end
      @data[key.to_s] = block_given? ? yield : value
    end

    def set?(key)
      validate_key!(key)
      @data.keys.include?(key.to_s)
    end

    def load(data)
      data.each do |key, value|
        validate_key!(key)
        @data[key.to_s] = value
      end
    end

    def reset
      @data = {}
    end

    private

    def validate_key!(key)
      unless key.is_a?(::String) || key.is_a?(::Symbol) || key.is_a?(::Array) \
        || key.is_a?(::Hash)
        raise ::PoroValidator::InvalidType.new(
          "only String, Symbol, Array or Hash are allowed! invalid key: #{key.inspect}"
        )
      end
    end
  end
end
