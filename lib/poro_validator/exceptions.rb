module PoroValidator
  class Exceptions < StandardError
    def initialize(message = nil, object = nil)
      super(message)
    end
  end

  class ConfigError < Exceptions; end
  class ValidatorNotFound < Exceptions; end
  class InvalidCondition < Exceptions; end
  class InvalidType < Exceptions; end
  class OverloadriddenRequired < Exceptions; end
  class InvalidValidator < Exceptions; end
end
