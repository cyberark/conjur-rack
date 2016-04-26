require 'rubygems'
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift File.join(File.dirname(__FILE__), "lib")

# Allows loading of an environment config based on the environment
require 'rspec'
require 'rspec/its'
require 'securerandom'

RSpec.configure do |config|
end

