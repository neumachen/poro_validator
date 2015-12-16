module TestHelpers
  class TestEntity
    attr_accessor :name
  end

  class TestEntityValidator
    include PoroValidator.validator

    validates :name, presence: true
  end
end
