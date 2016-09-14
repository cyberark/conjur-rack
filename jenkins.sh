#!/bin/bash -e

bundle update
env CONJUR_ENV=ci bundle exec rake spec
