#!/bin/bash -e

TEST_IMAGE='ruby:2.3.4'
BUNDLER_VERSION="2.1.4"

rm -f Gemfile.lock

docker run --rm \
  -v "$PWD:/usr/src/app" \
  -w /usr/src/app \
  -e CONJUR_ENV=ci \
  -e BUNDLER_VERSION=$BUNDLER_VERSION \
  $TEST_IMAGE \
  bash -c "gem update --system && gem uninstall -i /usr/local/lib/ruby/gems/2.3.0 bundler && gem install bundler -v $BUNDLER_VERSION && bundle update && bundle exec rake spec"
