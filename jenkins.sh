#!/bin/bash -e

gem install bundler
bundle update
env CONJUR_ENV=ci bundle exec rake spec
