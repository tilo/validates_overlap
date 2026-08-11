require_relative 'lib/validates_overlap/version'

Gem::Specification.new do |s|
  s.name = 'validates_overlap'
  s.version = ValidatesOverlap::VERSION

  s.authors = ['Robin Bortlik', 'Tilo Sloboda']
  s.description = 'Adds ActiveRecord validations that prevent overlapping date/time ranges — bookings, reservations, meetings, shifts. One SQL query; supports scoping and open-ended ranges'
  s.email = ['robinbortlik@gmail.com', 'tilo.sloboda@gmail.com']
  s.extra_rdoc_files = [
    'README.md'
  ]
  s.files = Dir['lib/**/*'] + %w[MIT-LICENSE README.md CHANGELOG.md CONTRIBUTORS.md]

  s.homepage = 'https://github.com/tilo/validates_overlap'
  s.licenses = ['MIT']
  s.require_paths = ['lib']
  s.summary = 'This gem helps validate records with time overlap.'

  s.metadata = {
    'source_code_uri' => "https://github.com/tilo/validates_overlap/tree/v#{s.version}",
    'bug_tracker_uri' => 'https://github.com/tilo/validates_overlap/issues',
    'changelog_uri' => 'https://github.com/tilo/validates_overlap/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://www.rubydoc.info/gems/validates_overlap',
    'rubygems_mfa_required' => 'true'
  }

  s.add_dependency 'activerecord', '>= 6.0.0'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rails'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
end
