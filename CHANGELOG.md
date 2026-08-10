# ValidatesOverlap 1.x Change Log

## 1.2.0 (2026-08-10)

RSpec tests: **85 → 102** (+17 tests)

### Bug Fixes

  - the validator is now stateless and thread-safe — fixes [Issue #50](https://github.com/tilo/validates_overlap/issues/50): concurrent validations of the same model class could corrupt each other's query, because Rails shares one validator instance per class and the query lived on it as instance state (intermittent `ActiveRecord::PreparedStatementInvalid`, or silently wrong validation results). Thanks to [Jorge Santos](https://github.com/jsantos) for the report
  - string range columns raised `TypeError` because a default shift of `0` was added even when no shift was configured — shifts are now only applied when set
  - the record's primary key is now passed to the database as a bind value when a persisted record is excluded from the comparison — it was interpolated into the SQL, which broke string keys containing a quote

### Improvements

  - documented in the README that `start_shift` / `end_shift` work in both directions: widening the range enforces a minimum gap, shrinking it tolerates a specified amount of overlap — now locked in by specs
  - the overlap check works on any orderable column type, now covered by specs for integer and string ranges
  - test coverage: real UUID/string primary key test restored (lost in a 2019 refactor), new tests for `:scoped_model`, literal scope values, and the two-attributes requirement; the long-disabled endless-objects test was fixed and re-enabled — the suite has no pending tests

### Internal

  - removed the accessors `sql_conditions`, `sql_values`, and `scoped_model` from `OverlapValidator` — they were the shared state; the query-building methods now take and return their inputs

## 1.1.0 (2026-08-07)

RSpec tests: **81 → 85** (+4 tests)

First release under new maintainership — [Tilo Sloboda](https://github.com/tilo) took over maintenance from [Robin Bortlik](https://github.com/robinbortlik) in August 2026. Thank you, Robin, for creating this gem and maintaining it for many years! ❤️

### Bug Fixes

  - fixed [Issue #54](https://github.com/tilo/validates_overlap/issues/54): a scope naming an enum attribute as a symbol (e.g. `scope: [:kind]`) crashed with `NoMethodError`. Thanks to [Nujian Den Mark Meralpis](https://github.com/denmarkmeralpis) ([PR #55](https://github.com/tilo/validates_overlap/pull/55)); covered by a new regression test

### Improvements

  - verified support for Rails 6.1, 7.0, 7.1, 7.2, 8.0, and 8.1 on Ruby 3.0–3.4 — an 18-cell GitHub Actions matrix now runs on every push (the first working CI since 2019)
  - the gem now depends on `activerecord` instead of the full `rails` meta-gem, so it no longer pulls actionpack etc. into your bundle (version floor unchanged: `>= 6.0`)
  - the gem package now ships only `lib/`, README, and license — previously the entire test app was packaged into the gem
  - test suite modernized: migrated from the long-dead `factory_girl` to `factory_bot`, runs on current Ruby/Rails, SimpleCov added with 100% line coverage, new tests for nil scope values (`IS NULL` matching) and symbol enum scopes
  - the gem version now lives in `ValidatesOverlap::VERSION` (`lib/validates_overlap/version.rb`); the `VERSION` file is gone
  - README: badges, Ruby/Rails compatibility matrix, clearer description of what the gem does

## 1.0.0 (2019-11-17)

  - Rails 6 support; support for Rails 3, 4, and 5 dropped — use version 0.8.6 for those. Thanks to [Robin Bortlik](https://github.com/robinbortlik)
  - avoid implicit `scoped_model.all` delegation in the validation ([PR #52](https://github.com/tilo/validates_overlap/pull/52)). Thanks to [Ryuta Kamizono](https://github.com/kamipo)
  - Russian validation error message ([PR #47](https://github.com/tilo/validates_overlap/pull/47)). Thanks to [Alexander Gornov](https://github.com/Zmokizmoghi)

## 0.8.6 (2017-11-20) and earlier

  - releases from 2011 through 2017 by [Robin Bortlik](https://github.com/robinbortlik) and contributors were not tracked in a changelog; see the git history and [CONTRIBUTORS.md](CONTRIBUTORS.md)
