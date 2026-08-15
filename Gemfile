source 'https://rubygems.org'

gemspec

# only when running the suite against MySQL (DB=mysql): the mysql2 gem needs
# MySQL client libraries to compile, so it must not burden a normal install
gem 'mysql2' if ENV['DB'] == 'mysql'
