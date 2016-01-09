# PoroValidator::Validator is a lightweight Plain Old Ruby Object
# validator.
#
# @since 0.0.1
module PoroValidator
  # Allow access to the anonymouse validator module
  #
  # @example
  # class FoodValidator
  #   include PoroValidator.validator
  #
  # end

  def self.validator
    mod = Module.new
    mod.define_singleton_method(:included) do |base|
      base.send(:include, ::PoroValidator::Validator)
    end
    mod
  end

  def self.configuration
    @configuration || Configuration.new
  end
end

# Base Classes
require "poro_validator/version"
require "poro_validator/error_store"
require "poro_validator/errors"
require "poro_validator/exceptions"
require "poro_validator/configuration"
require "poro_validator/validator/base_class"
require "poro_validator/validator/validation"
require "poro_validator/validator/validations"
require "poro_validator/validator/conditions"
require "poro_validator/validator/factory"
require "poro_validator/validator/context"

# Validators
require "poro_validator/validators/base_class"
require "poro_validator/validators/presence_validator"
require "poro_validator/validators/format_validator"
require "poro_validator/validators/with_validator"
require "poro_validator/validators/inclusion_validator"
require "poro_validator/validators/exclusion_validator"
require "poro_validator/validators/integer_validator"
require "poro_validator/validators/float_validator"
require "poro_validator/validators/length_validator"
require "poro_validator/validators/numeric_validator"

# Modules
require "poro_validator/validator"
