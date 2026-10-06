# Development image for poro_validator.  Default base is Ruby 4.0.7-slim-trixie
# (pinned digest).  Set RUBY_BASE (compose.yaml dev34) for the Ruby 3.4.11
# alternative.
# Exact digests from Docker Hub, 2026-10-01, aarch64.
#
# Gems and Bundler config live in /usr/local/bundle (the base image's
# GEM_HOME and BUNDLE_APP_CONFIG).  Ignore Bundler config files, never
# re-resolve the lockfile, and keep Coveralls off.

ARG RUBY_BASE=ruby:4.0.7-slim-trixie@sha256:db9ddd17cc6ac603f2497d98ac5c88e4118908d6f9a45f2422ebee141f91e485

FROM ${RUBY_BASE}

ENV BUNDLE_GEMFILE=/app/Gemfile.test \
    BUNDLE_FROZEN=true \
    BUNDLE_IGNORE_CONFIG=true \
    COVERALLS=false

WORKDIR /app
COPY Gemfile.test Gemfile.test.lock ./
RUN gem install bundler -v 2.6.9 && bundle _2.6.9_ install && bundle _2.6.9_ list