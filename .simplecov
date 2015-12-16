require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  add_filter 'spec'

  add_group 'Validator', 'lib/poro_validator/validator'
  add_group 'Validators', 'lib/poro_validator/validators'
end
