#!/bin/bash -e

rm -f Gemfile.lock

docker run --rm \
  -v $PWD:/usr/src/app \
  -w /usr/src/app \
  -e CONJUR_ENV=ci \
  ruby:2.2.4 \
  sh -c "bundle update && bundle exec rake spec"
