#!/bin/bash -ex

echo "*** Starting Publish"

git clone git@github.com:conjurinc/release-tools.git

export PATH=$PWD/release-tools/bin/:$PATH

echo "***--- Starting Summon"
summon --yaml "RUBYGEMS_API_KEY: !var rubygems/api-key" \
  publish-rubygem conjur-rack
echo "***--- Finished Summon"

echo "*** Finished Publish"
