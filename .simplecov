# Coverage stays local (coverage/) unless Coveralls is explicitly requested,
# because its formatter uploads results to coveralls.io.
if ENV['COVERALLS'] == 'true'
  require 'coveralls'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ]
end

SimpleCov.start do
  add_filter 'spec'

  add_group 'Validator', 'lib/poro_validator/validator'
  add_group 'Validators', 'lib/poro_validator/validators'
end
