# Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/tilo/validates_overlap/issues). For a change in behavior, please include a test that covers it.

## Running the tests

The test suite runs against three database adapters. SQLite is the default and needs no setup:

```bash
bundle install
bundle exec rspec        # or: bundle exec rake
```

### PostgreSQL

Needs a running PostgreSQL server and a test database:

```bash
createdb validates_overlap_test

DB=postgres bundle exec rspec            # the main suite, on the PostgreSQL adapter
DB=postgres bundle exec rspec spec_pg    # PostgreSQL-only specs: exclusion constraints, native range columns
```

Connection settings default to `localhost` and your OS user; override with `PGHOST`, `PGUSER`, `PGPASSWORD` if your setup differs. The `spec_pg` specs need permission to `CREATE EXTENSION btree_gist`.

The specs in `spec_pg_18/` cover the `without_overlaps` constraint option and need a PostgreSQL 18+ server. A second server version runs fine next to an older one (`brew install postgresql@18`, set `port = 5433` in its `postgresql.conf`), then:

```bash
PGPORT=5433 DB=postgres bundle exec rspec spec_pg_18
```

### MySQL

Needs a running MySQL server. The `mysql2` gem is only part of the bundle when `DB=mysql` is set, and its C extension needs to know where MySQL is installed when it compiles — shown here for Homebrew (adjust the formula name if yours is versioned, e.g. `mysql@8.4`):

```bash
bundle config --local build.mysql2 --with-mysql-config=$(brew --prefix mysql)/bin/mysql_config
DB=mysql bundle install
mysql -u root -e 'CREATE DATABASE IF NOT EXISTS validates_overlap_test'

DB=mysql bundle exec rspec
```

Connection settings default to `127.0.0.1` / `root` / no password; override with `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`.

### All three in one command

```bash
bundle exec rake spec:all        # SQLite, then PostgreSQL (incl. spec_pg), then MySQL
```

`rake spec:postgres` and `rake spec:mysql` run a single adapter. The default `rake` / `rake spec` stays SQLite-only so it works without any database server — that is also what every cell of the CI matrix runs; the PostgreSQL and MySQL suites have their own CI jobs.

SimpleCov merges the coverage of all adapter runs into one report (`coverage/index.html`).
