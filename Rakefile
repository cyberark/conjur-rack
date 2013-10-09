require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--format doc"
  unless ENV["CONJUR_ENV"] == "ci"
    t.rspec_opts << " --color"
  end
end

task :default => :spec