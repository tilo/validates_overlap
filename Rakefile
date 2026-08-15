require 'rubygems'
require 'bundler'
require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'rdoc/task'
require File.expand_path('lib/validates_overlap/version', __dir__)

begin
  Bundler::GemHelper.install_tasks
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end


RSpec::Core::RakeTask.new(:spec)

task default: :spec

# The PostgreSQL and MySQL tasks need a running local server and a
# validates_overlap_test database — see CONTRIBUTING.md for the setup.
namespace :spec do
  desc 'Run the suite against PostgreSQL, including the PostgreSQL-only specs in spec_pg/'
  task :postgres do
    sh({ 'DB' => 'postgres' }, 'bundle exec rspec')
    sh({ 'DB' => 'postgres' }, 'bundle exec rspec spec_pg')
  end

  desc 'Run the suite against MySQL (needs a one-time DB=mysql bundle install)'
  task :mysql do
    sh({ 'DB' => 'mysql' }, 'bundle exec rspec')
  end

  desc 'Run all three adapter suites: SQLite, PostgreSQL (incl. spec_pg/), MySQL'
  task all: ['spec', 'spec:postgres', 'spec:mysql']
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "validates_overlap #{ValidatesOverlap::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
