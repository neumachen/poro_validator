# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'poro_validator/version'

Gem::Specification.new do |spec|
  spec.name          = "poro_validator"
  spec.version       = PoroValidator::VERSION
  spec.authors       = ["Kareem Gan"]
  spec.email         = ["kareemgan@gmail.com"]

  spec.summary       = %q{A PORO (Plain Old Ruby Object) validator.}
  spec.description   = %q{Validations for ruby objects or POROs.}
  spec.homepage      = "https://github.com/magicalbanana/poro_validator"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "http://mygemserver.com"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency("bundler")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("rspec")
  spec.add_development_dependency('simplecov')
  spec.add_development_dependency('coveralls')
  spec.add_development_dependency('recursive-open-struct')
  spec.add_development_dependency('nyan-cat-formatter')
  # = MANIFEST =
  spec.files = %w[
    CODE_OF_CONDUCT.md
    Gemfile
    LICENSE.txt
    README.md
    Rakefile
    lib/poro_validator.rb
    lib/poro_validator/configuration.rb
    lib/poro_validator/error_store.rb
    lib/poro_validator/errors.rb
    lib/poro_validator/exceptions.rb
    lib/poro_validator/validator.rb
    lib/poro_validator/validator/base_class.rb
    lib/poro_validator/validator/conditions.rb
    lib/poro_validator/validator/context.rb
    lib/poro_validator/validator/factory.rb
    lib/poro_validator/validator/validation.rb
    lib/poro_validator/validator/validations.rb
    lib/poro_validator/validators/base_class.rb
    lib/poro_validator/validators/exclusion_validator.rb
    lib/poro_validator/validators/float_validator.rb
    lib/poro_validator/validators/format_validator.rb
    lib/poro_validator/validators/inclusion_validator.rb
    lib/poro_validator/validators/integer_validator.rb
    lib/poro_validator/validators/length_validator.rb
    lib/poro_validator/validators/numeric_validator.rb
    lib/poro_validator/validators/presence_validator.rb
    lib/poro_validator/validators/range_array_validator.rb
    lib/poro_validator/validators/with_validator.rb
    lib/poro_validator/version.rb
    poro_validator.gemspec
    spec/features/composable_validations_spec.rb
    spec/features/inheritable_spec.rb
    spec/features/nested_validations_spec.rb
    spec/lib/poro_validator/configuration_spec.rb
    spec/lib/poro_validator/error_store_spec.rb
    spec/lib/poro_validator/errors_spec.rb
    spec/lib/poro_validator/validator/base_class_spec.rb
    spec/lib/poro_validator/validator/conditions_spec.rb
    spec/lib/poro_validator/validator/factory_spec.rb
    spec/lib/poro_validator/validator/validation_spec.rb
    spec/lib/poro_validator/validator/validations_spec.rb
    spec/lib/poro_validator/validator_spec.rb
    spec/lib/poro_validator/validators/base_class_spec.rb
    spec/lib/poro_validator/validators/exclusion_validator_spec.rb
    spec/lib/poro_validator/validators/float_validator_spec.rb
    spec/lib/poro_validator/validators/format_validator_spec.rb
    spec/lib/poro_validator/validators/inclusion_validator_spec.rb
    spec/lib/poro_validator/validators/integer_validator_spec.rb
    spec/lib/poro_validator/validators/length_validator_spec.rb
    spec/lib/poro_validator/validators/numeric_validator_spec.rb
    spec/lib/poro_validator/validators/presence_validator_spec.rb
    spec/lib/poro_validator/validators/with_validator_spec.rb
    spec/poro_validator_spec.rb
    spec/spec_helper.rb
    spec/support/spec_helpers/concerns.rb
    spec/support/spec_helpers/validator_test_macros.rb
  ]
  # = MANIFEST =
end
