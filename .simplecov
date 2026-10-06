# Configuration only; SimpleCov.start is called explicitly in spec_helper.rb.
# Coverage stays local (coverage/) unless Coveralls is explicitly requested,
# because its formatter uploads results to coveralls.io.
if ENV['COVERALLS'] == 'true'
  require 'coveralls'
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
end

# Only the top-level spec/ directory. Filters see paths relative to the
# project root, like "/spec/spec_helper.rb", and a string filter matches
# anywhere in them: 'spec' would also drop lib/.../stable_inspect.rb.
SimpleCov.skip %r{\A/spec/}

SimpleCov.group 'Validator', 'lib/poro_validator/validator'
SimpleCov.group 'Validators', 'lib/poro_validator/validators'
