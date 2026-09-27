require 'open3'
require 'rbconfig'

# Requires the gem in a separate Ruby process with an empty environment, so
# the result cannot depend on anything this process or Bundler has loaded.
# Deliberately does not require spec_helper: it requires the gem in this
# process, so a load failure would abort the run before this example could
# report it.
RSpec.describe "requiring poro_validator in a fresh Ruby process" do
  let(:lib) { File.expand_path('../lib', __dir__) }

  let(:script) do
    <<-'RUBY'
      require 'poro_validator'

      puts File.realpath($LOADED_FEATURES.grep(%r{/poro_validator\.rb\z}).first)

      validator = Class.new do
        include PoroValidator.validator

        validates :age, numeric: { min: 18, max: 2**64 }
        validates :rating, numeric: 1..5
      end.new

      puts validator.valid?({ age: 18, rating: 5 })
      puts validator.valid?({ age: 2**64 + 1, rating: 0 })
      puts validator.errors.count
    RUBY
  end

  it "loads this checkout and validates integer numeric options" do
    out, err, status = Open3.capture3(
      {}, RbConfig.ruby, '-I', lib, '-e', script, unsetenv_others: true
    )

    expect(status).to be_success, "exit status #{status.exitstatus}:\n#{err}"
    expect(out.lines.map(&:chomp)).to eq([
      File.realpath(File.join(lib, 'poro_validator.rb')),
      'true',
      'false',
      '2'
    ])
  end
end
