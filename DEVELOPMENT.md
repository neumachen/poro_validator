# Development

Every project command runs inside a container: dependency installation,
tests, builds, linting, probes, benchmarks and Git commands on this
repository. On the host, only file reading and editing and container or UI
orchestration happen, so the host needs [mise](https://mise.jdx.dev/) and
Docker with Compose v2; no host Ruby or gems are installed or used. There is no
fallback to host execution, and future CI, such as GitHub Actions, follows the
same rule.

## Supported Ruby versions

The gem requires Ruby ≥ 3.4. Tested branches:

| Branch | Image | Bundler | Status |
|---|---|---|---|
| Ruby 4.0.7 | `ruby:4.0.7-slim-trixie@sha256:db9ddd17…` (multi-arch OCI index; aarch64 tested) | 2.6.9 | Default development runtime |
| Ruby 3.4.11 | `ruby:3.4.11-slim-trixie@sha256:4677fd16…` (multi-arch OCI index; aarch64 tested) | 2.6.9 | Maintained 3.4 alternative |
| Ruby 2.7.8 | `ruby:2.7-slim` | — | Historical comparison only; EOL, not supported |

Ruby 3.4.6 was the diagnostic baseline during the early revival; it is not a
separately supported version.

The Docker image digests are pinned for reproducibility.

## Tasks

Run these from the repository root. If mise reports that `mise.toml` is not
trusted, review it and run `mise trust` once.

| Command | What it does |
|---|---|
| `mise run setup` | Builds the Ruby-4.0 dev image |
| `mise run setup:rb34` | Builds the Ruby-3.4 dev image |
| `mise run test` | Runs RSpec on Ruby 4.0 (arguments after `--` go to rspec) |
| `mise run test:rb34` | Runs RSpec on Ruby 3.4 (arguments after `--` go to rspec) |
| `mise run test:load` | Runs the fresh-process load regression on Ruby 4.0 |
| `mise run shell` | Opens a shell in a throwaway Ruby-4.0 container |
| `mise run shell:rb34` | Opens a shell in a throwaway Ruby-3.4 container |
| `mise run verify:clean` | Builds the Ruby-4.0 image without cache in an isolated image, runs the suite as your UID/GID, then removes only that image |
| `mise run matrix:build` | Builds both Ruby images |
| `mise run matrix:test` | Runs RSpec on both Ruby versions |

`test`, `test:load` and `shell` run `setup` first, so the first `mise run test`
builds the image; later runs reuse Docker's build cache. Pass RSpec arguments
after `--`; the task exits with RSpec's status:

```sh
mise run test -- --seed 1234
mise run test:rb34 -- spec/lib/poro_validator/validators/numeric_validator_spec.rb
```

The suite runs in random order and prints its seed.

After `verify:clean`, the isolated image (tagged `poro_validator-clean-<pid>`) is removed;
the normal development image tags are not affected.

## The container

- `Dockerfile` builds from `ruby:4.0.7-slim-trixie` (or
  `ruby:3.4.11-slim-trixie` via the rb34 profile), each pinned to its
  multi-platform OCI index digest. It copies in only `Gemfile.test` and
  `Gemfile.test.lock` and installs the locked gems with Bundler 2.6.9 into
  the image (`/usr/local/bundle`). Containers run with frozen and isolated
  bundler configuration.
- `compose.yaml` mounts the checkout read-only at `/app`, so a test run cannot
  change the source or the lockfile. The one writable mount is `coverage/`.
  Containers run as your UID and GID and have no network.
- `verify:clean` uses `docker build --no-cache` to build an isolated image
  tagged with the shell PID (`poro_validator-clean-$$`). If the tag already
  exists it refuses to overwrite it. It runs the suite as the caller's
  UID/GID in a throwaway container, then removes only that image. Normal
  development tags are unaffected.
- `compose.yaml` mounts the checkout read-only at `/app`, so a test run cannot
  change the source or the lockfile. The one writable mount is `coverage/`.
  Containers run as your UID and GID and have no network.
- The whole checkout is mounted, so its files remain visible inside the
  container, including any `.bundle/` directory created on the host. Bundler
  ignores its config files, never re-resolves the lockfile, and uses the gems
  installed in the image at `/usr/local/bundle`. Your home directory is not
  mounted, and Compose passes no host environment variables in (it only uses
  your UID and GID to set the container user). `.dockerignore` limits only the
  image build context.

## Coverage

SimpleCov writes an HTML report to `coverage/` (ignored by git), owned by you.
Coveralls cannot run: it is not in the test bundle, `.simplecov` only loads it
when `COVERALLS=true`, the image sets `COVERALLS=false`, and test containers
have no network.

## Loading in a fresh process

`spec/fresh_process_require_spec.rb` starts a separate Ruby with an empty
environment and `-I lib`, requires the gem, checks that it was loaded from the
mounted checkout, and runs a numeric validation. It does not require
`spec_helper`, so it can still report a load failure on its own
(`mise run test:load`).

## Changing dependencies

The checks above never change `Gemfile.test.lock`. To change dependencies,
edit `Gemfile.test`, regenerate the lockfile with the image's Bundler, review
the diff, then run `mise run setup`:

```sh
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -e BUNDLE_FROZEN=false \
  -v "$PWD:/app" -w /app poro_validator-dev-rb40 bundle lock
```

## Rake tasks

`rake gemspec` validates the package manifest without creating a payload.
`rake build` (which depends on `gemspec`) builds the gem into `pkg/`. Both work
without Git. The resulting package contains all `lib/` files plus `README.md`,
`LICENSE.txt`, `CODE_OF_CONDUCT.md` and the gemspec itself, and excludes `spec/`,
`Gemfile`, `Rakefile`, lockfiles and container/tool configuration. `rake release`
is a separate protected operation that can commit, tag, push and upload.

The gemspec selects files using absolute paths derived from its own location,
so it loads correctly from any working directory — not just the project root.

### Building and verifying the installed artifact

The checkout is mounted read-only in the development container. Build from a
writable disposable copy, then verify the installed gem in a separate plain-Ruby
consumer container with no checkout or development bundle mounts.

**Prerequisites** — build the development images once from the repository root:

```sh
mise run setup          # Ruby 4.0.7 (default)
mise run setup:rb34     # Ruby 3.4.11
```

The plain-Ruby consumer bases are pinned in `Dockerfile`/`compose.yaml` and must
already be available locally (verified offline, no pull):

- Ruby 4.0.7: `ruby:4.0.7-slim-trixie@sha256:db9ddd17cc6ac603f2497d98ac5c88e4118908d6f9a45f2422ebee141f91e485`
- Ruby 3.4.11: `ruby:3.4.11-slim-trixie@sha256:4677fd16f2b54ef534d18b0e34e20a15726b62c203cb996fd70297a058864c60`

**Procedure** — save as `build_and_verify.sh` and run from the repository root.
Set `RUBY` to `40` or `34`.

```sh
#!/bin/bash
set -uo pipefail

# --- Configuration ---
RUBY="40"
DEV_IMAGE="poro_validator-dev-rb${RUBY}"
case "$RUBY" in
  40) BASE_IMAGE="ruby:4.0.7-slim-trixie@sha256:db9ddd17cc6ac603f2497d98ac5c88e4118908d6f9a45f2422ebee141f91e485" ;;
  34) BASE_IMAGE="ruby:3.4.11-slim-trixie@sha256:4677fd16f2b54ef534d18b0e34e20a15726b62c203cb996fd70297a058864c60" ;;
  *)  echo "Unknown RUBY: $RUBY" >&2; exit 2 ;;
esac
PROJECT="$(pwd)"
EXPORT="$(mktemp -d)"
CONSUMER="$(mktemp -d)"
VERIFY_SCRIPT="$(mktemp)"

cleanup() {
  rm -rf "$EXPORT" "$CONSUMER" "$VERIFY_SCRIPT"
}

# --- Builder container: read-only source, writable temp directory ---
build_status=0
docker run --rm --network none --pull=never \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$PROJECT:/app:ro" \
  -v "$EXPORT:/export:rw" \
  -w /app \
  "$DEV_IMAGE" bash -c '
    src=$(mktemp -d)
    cp -r /app/. "$src/"
    cd "$src"
    gem build poro_validator.gemspec || exit 1
    version=$(ruby -e "puts Gem::Specification.load(ARGV[0]).version" poro_validator.gemspec)
    gem_file="poro_validator-${version}.gem"
    [ -f "$gem_file" ] || { echo "Build failed: $gem_file not produced" >&2; exit 1; }
    cp "$gem_file" /export/
  ' || build_status=$?

if [ "$build_status" -ne 0 ]; then
  echo "Build failed — not installing" >&2
  cleanup
  exit 1
fi

# --- Separate plain-Ruby consumer container ---
work_status=0
verify_script="$VERIFY_SCRIPT"
cat > "$verify_script" << 'RUBY'
  Gem.paths = { "GEM_HOME" => "/probes/gems", "GEM_PATH" => "/probes/gems" }
  require "rubygems"
  gem "poro_validator"
  require "poro_validator"

  path = $LOADED_FEATURES.find { |f| f.end_with?("poro_validator.rb") }
  abort "FAIL: not installed gem" unless path && path.start_with?(ENV["GEM_HOME"])

  entity_class = Class.new do
    attr_accessor :x
    def initialize(attrs = {})
      attrs.each { |k, v| send("#{k}=", v) }
    end
  end

  validator = Class.new { include PoroValidator.validator; validates :x, presence: true }.new

  # Valid input returns true
  raise "FAIL: valid input rejected" unless validator.valid?(entity_class.new(x: "value"))

  # Invalid input returns false with expected attribute error
  entity = entity_class.new(x: nil)
  raise "FAIL: invalid input accepted" if validator.valid?(entity)
  raise "FAIL: missing x error" if validator.errors.on(:x).empty?

  puts "OK: " + path
RUBY

docker run --rm --network none --pull=never \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e GEM_HOME=/probes/gems \
  -e GEM_PATH=/probes/gems \
  -v "$EXPORT:/artifact:ro" \
  -v "$CONSUMER:/probes:rw" \
  -v "$verify_script:/probes/verify.rb:ro" \
  -w /probes \
  "$BASE_IMAGE" bash -c '
    unset BUNDLE_GEMFILE RUBYLIB RUBYOPT
    version=$(ruby -e "puts Dir.glob(ARGV[0])[0].match(/(\d+\.\d+\.\d+)/)[1]" "/artifact/poro_validator-*.gem")
    gem_file="/artifact/poro_validator-${version}.gem"
    gem install --local --no-document "$gem_file" || exit 1
    ruby /probes/verify.rb
  ' || work_status=$?

# --- Cleanup and final status ---
cleanup_status=0
cleanup || cleanup_status=$?

if [ "$work_status" -ne 0 ]; then
  echo "Consumer verification FAILED" >&2
  exit 1
elif [ "$cleanup_status" -ne 0 ]; then
  echo "Verification succeeded but cleanup failed" >&2
  exit 1
fi

echo "Consumer verification passed"
```

The script:
- Determines the exact current gem version from gemspec metadata (not wildcard),
  so a successful build installs the fresh artifact even if stale copies exist.
- Stops before installation if building fails, even with stale artifacts present.
- Stops before verification if installation fails.
- Uses pinned digest references with `--pull=never` for offline verification.
- Preserves work failure status and returns nonzero if cleanup fails after success.
- Removes owned temporary resources in all paths.

**Run for both supported versions**:

```sh
bash build_and_verify.sh                # Ruby 4.0.7 (default)
sed 's/RUBY="40"/RUBY="34"/' build_and_verify.sh | bash  # Ruby 3.4.11
```

## Error path records (internal)

`ErrorStore` keeps an internal record of the path each entry was written
from. `WithValidator` reads those records when transferring child errors
during composition, so `errors.on([:address, :country, :code])` finds
messages produced by a child validator that recorded `[:country, :code]`.
`__path__` and `__append__` are internal helpers, not an API.

- `#set` with an ordinary nested path (a plain Array of Symbols and plain
  Strings, at least two names) records frozen copies of the names under the
  stored text. A literal key that renders to the same text, such as the String
  `"{:a=>:b}"`, records nothing, and other key shapes are not recorded.
- `set`, `load`, `reset` (so `Errors#clear_errors`) and `Errors#add` keep the
  records in step: an append through a key that does not name the recorded
  path, such as its String form, forgets the record. Only an `ErrorStore` or a
  subclass keeps records; any other object used as a store gets the plain
  append.
- Direct edits to `errors.store.data` are not tracked. Replacing a value under
  a recorded text keeps that text's record, and a direct delete or clear can
  leave records until `reset`. A custom `#get` that returns a wrapper
  forwarding `<<` can hide an append the same way. Records hold only names and
  text, never message Arrays.
- `inspect` and `Marshal.dump` now include the records (`@paths`). A store
  dumped by an earlier version loads and works without records, and reads
  return frozen names without changing a restored or frozen store. Whether an
  earlier version can read a newly dumped store is not tested.
- Recorded composed keys now use normal nested paths; there are no old
  serialized-key aliases. Equal paths merge without dropping duplicate
  messages; total count and per-path append order are preserved.
  `full_messages` grouping may change with Hash insertion order. Literal
  and unrecorded entries keep the storage-adoption fallback, and the raw-data
  metadata boundary is unchanged. See the [composed nested paths example](README.md#composed-nested-paths).
- The specs are `spec/lib/poro_validator/error_store_lifecycle_spec.rb`,
  `error_store_paths_spec.rb`, `errors_get_dispatch_spec.rb` and
  `errors_foreign_store_spec.rb`. `spec/fixtures/legacy/` holds payloads dumped
  by the library before this change; do not regenerate them with the current
  code.

## Continuous Integration

A GitHub Actions workflow (`.github/workflows/ci.yml`) runs on `push` and
`pull_request`, with no branch-name assumptions and no other triggers
(no schedule, `workflow_dispatch`, `pull_request_target`, or release
events). Permissions are read-only (`contents: read`); no secrets, write
tokens, caches, coverage upload, or artifact upload are used.

Jobs run on `ubuntu-24.04-arm`, matching the only architecture this
project's containers have been exercised on (AMD64 is not promised). The
matrix has two entries, one per supported Ruby branch, each selecting the
matching Compose profile and service already defined in `compose.yaml`:

| Matrix entry | Compose profile | Compose service |
|---|---|---|
| Ruby 4.0.7 | `rb40` | `dev` |
| Ruby 3.4.11 | `rb34` | `dev34` |

Each job: checks out the repository with `actions/checkout` pinned to a
full commit SHA (`3d3c42e5aac5ba805825da76410c181273ba90b1`, tag `v7.0.1`)
with `persist-credentials: false`; builds the selected Compose service from
the existing `Dockerfile` and locked `Gemfile.test.lock` (this build step
needs network to fetch gems, same as building the image locally); then runs
RSpec with two full-suite seeds and the fresh-process load spec inside the
built container, which runs with `network_mode: none` as already configured
in `compose.yaml`. `fail-fast: false` so one Ruby branch's failure doesn't
hide the other's result; no `continue-on-error` anywhere, so a nonzero
RSpec exit fails the job.

The workflow uses `docker compose` directly (the same commands `mise`'s
tasks and `script/matrix-test` wrap), so no host `mise` installation or
other GitHub Action beyond `actions/checkout` is required.

This workflow has been locally verified by running its underlying
`docker compose build`/`docker compose run` command sequence, for both
matrix entries, in disposable containers on this project's existing
pinned/cached images -- see `tmp/container-ci-evidence/COMPLETION-REPORT.md`.
It has not yet had an observed hosted GitHub Actions run; no status badge
is added until an owner-authorized hosted result exists.
