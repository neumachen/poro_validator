# Development

## Running the specs

The specs run against a dedicated, test-only Gemfile, `Gemfile.test`, and its
lockfile, `Gemfile.test.lock`, which is meant to be committed alongside it (git
does not ignore it). The main `Gemfile` is unchanged; its optional debugging
tools (one sourced from Git) and the gemspec's Coveralls dependency are not
needed to run the specs.

The diagnostic baseline is Ruby 3.4.6 with Bundler 2.6.9, the Bundler version
that ships with Ruby 3.4.6: the lockfile was generated and checked with them.
That records the environment used to verify this setup; it does not declare
which Ruby versions the gem supports.

Select Ruby 3.4.6 explicitly, so a version manager's shims cannot substitute
another Ruby: set `RUBY_BIN` to the `bin` directory of a Ruby 3.4.6
installation (with mise, for example, `"$(mise where ruby@3.4.6)/bin"`). Then,
from the repository root:

```sh
RUBY_BIN=/path/to/ruby-3.4.6/bin
export BUNDLE_GEMFILE="$PWD/Gemfile.test"
export BUNDLE_PATH="$PWD/.bundle"  # install inside this checkout (ignored by git)
export BUNDLE_FROZEN=true          # install exactly what Gemfile.test.lock records
"$RUBY_BIN/ruby" --version                     # expect: ruby 3.4.6 ...
"$RUBY_BIN/ruby" "$RUBY_BIN/bundle" --version  # expect: Bundler version 2.6.9
"$RUBY_BIN/ruby" "$RUBY_BIN/bundle" install
"$RUBY_BIN/ruby" "$RUBY_BIN/bundle" exec rspec
```

With `BUNDLE_FROZEN=true`, Bundler refuses to re-resolve or rewrite the
lockfile, and it checks each downloaded gem against the lockfile's
`CHECKSUMS`. Because `BUNDLE_GEMFILE` points at `Gemfile.test`, RubyGems runs
the Bundler version recorded in `Gemfile.test.lock` if it is installed; the
version check above confirms it.

The suite runs in random order. RSpec prints the seed; rerun an order by adding
`--seed <seed>` to the `exec rspec` command.

To change dependencies, edit `Gemfile.test`, run `bundle lock` with the same
Ruby and without `BUNDLE_FROZEN`, and review the lockfile diff.

## Coverage

`spec/spec_helper.rb` starts SimpleCov, which writes an HTML report to
`coverage/` (ignored by git). Coveralls is not part of the test bundle:
`.simplecov` only loads it when `COVERALLS=true`, because its formatter uploads
results to coveralls.io.

## Loading in a fresh process

`spec/fresh_process_require_spec.rb` starts a separate Ruby with an empty
environment and `-I lib`, requires the gem, checks that it was loaded from this
checkout, and runs a numeric validation. It does not require `spec_helper`, so
it can still report a load failure when run on its own:

```sh
"$RUBY_BIN/ruby" "$RUBY_BIN/bundle" exec rspec spec/fresh_process_require_spec.rb
```

## Rake tasks

The Rakefile's `build`, `gemspec` and `release` tasks regenerate the gemspec,
commit, tag, push and publish the gem. They are not needed to run the specs.
