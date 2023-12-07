#!/bin/bash -eux

echo "==> Starting test.sh"

rm -f Gemfile.lock

echo "==> Docker Run"

docker run --rm \
    --volume $PWD:/usr/src/app \
    --workdir /usr/src/app cyberark/ubuntu-ruby-builder \
    bash -c 'git config --global --add safe.directory /usr/src/app && apt update && apt search libyaml && apt install libyaml-dev && gem update --system && bundle install && gem install spec && bundle install && bundle update && bundle exec rspec' 

echo "==> End of test.sh"