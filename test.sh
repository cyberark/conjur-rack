#!/bin/bash -e

TEST_IMAGE='ruby:2.5'

rm -f Gemfile.lock

docker run --rm \
  -v "$PWD:/usr/src/app" \
  -w /usr/src/app \
  -e CONJUR_ENV=ci \
  $TEST_IMAGE \
  bash -c "gem update --system && gem install bundler:2.2.18 && bundle update && bundle exec rake spec"
