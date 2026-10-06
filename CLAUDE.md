# Notes for coding agents

- Run every project command inside a container: dependency installation,
  tests, builds, linting, probes, benchmarks and Git commands on this
  repository. There is no host fallback: if Docker is unavailable, stop and
  report the problem.
- On the host, only read and edit files and orchestrate containers or the UI
  (for example mise, Docker and Docker Compose).
- Ruby, Bundler and RSpec run in the development container through the mise
  tasks (`mise run setup`, `mise run test`, `mise run test:load`,
  `mise run shell`, `mise run verify:clean`). Never install or use a host Ruby
  or host gems.
- Future CI, such as GitHub Actions, follows the same rule.
- See DEVELOPMENT.md for details.
