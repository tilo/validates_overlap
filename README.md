# ValidatesOverlap

![Gem Version](https://img.shields.io/gem/v/validates_overlap) [![RSpec](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml/badge.svg)](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml) [![codecov](https://codecov.io/gh/tilo/validates_overlap/branch/main/graph/badge.svg)](https://app.codecov.io/gh/tilo/validates_overlap/tree/main) [![Downloads](https://img.shields.io/gem/dt/validates_overlap)](https://rubygems.org/gems/validates_overlap) [![RubyGems](https://img.shields.io/badge/RubyGems-validates__overlap-brightgreen?logo=rubygems&logoColor=white)](https://rubygems.org/gems/validates_overlap) [![Ruby Toolbox](https://img.shields.io/badge/Ruby%20Toolbox-validates__overlap-brightgreen)](https://www.ruby-toolbox.com/projects/validates_overlap)

`validates_overlap` provides an ActiveRecord validator for resources that must not overlap, e.g. in datetime. Think rentals, meetings, bookings, work shifts, or assignments where the same resource cannot be assigned to multiple people or entities during overlapping time periods. But it also works for other domains than datetime (see below).

You specify the attributes defining a datetime range — typically two, such as `starts_at` and `ends_at`, or on PostgreSQL a single native range column — and the validator checks with a single SQL query whether another record overlaps that range; no records are loaded for the comparison. If one does, the record receives a normal validation error.

It also supports scoped validation (per user, room, resource, etc.), open-ended ranges (a nil start or end counts as extending forever), ranges that may touch at their boundaries (`exclude_edges`), required gaps between ranges or a tolerated amount of overlap (`start_shift` / `end_shift`), associations, and retrieving the conflicting records.

## Quick Start

Add to your gemfile

```ruby
gem 'validates_overlap'
```

In your model

```ruby
validates :starts_at, :ends_at, :overlap => true

# or scoped, e.g. per user:
validates :starts_at, :ends_at, :overlap => {:scope => "user_id"}
```

All options — scopes, edge handling, gaps and tolerated overlap, custom messages, associations, retrieving the conflicting records — are described in the [Option Reference](docs/options.md).

## Documentation

  * [Examples and Introduction](docs/_introduction.md)
  * [Option Reference](docs/options.md)
  * [Range Types and Domains](docs/range_types.md)
  * [PostgreSQL: Exclusion Constraints](docs/postgresql.md)

## Range Types

The range columns don't have to be dates or times: any linearly orderable column type works, such as integer ranges (ticket number blocks), decimal ranges (price bands), or string ranges (alphabetical partitions). ⚠️ Cyclic (wrap-around) domains — time-of-day, day-of-week, month numbers, angles — can NOT be validated for overlap; the validator refuses `:time` columns outright. [Range Types and Domains](docs/range_types.md) explains both halves.

## ⚠️ Concurrent Writes

Validation alone can not prevent double-booking under concurrent writes: two simultaneous requests can both pass the check and both save — the same limitation as `validates_uniqueness_of`. On PostgreSQL, the gem's migration helpers generate an exclusion constraint that closes this race at the database level:

```ruby
add_overlap_constraint :meetings, :starts_at, :ends_at, scope: :user_id
```

## ⭐ PostgreSQL Support
Native PostgreSQL range columns are supported as well — declare the validation with the single range attribute (`validates :period, overlap: ...` on a `tstzrange` column). See [PostgreSQL: Exclusion Constraints](docs/postgresql.md) for the helpers, the range-column semantics, the companion concern that turns the constraint violation into a normal validation error, and the equivalent hand-written SQL.

## Note: Add an index — the overlap check runs on every save

The validation runs one `EXISTS` query per save. Without a suitable index that query is a full table scan — invisible at 1,000 rows, painful at 1,000,000. Add a composite index with your scope columns first, then the range columns:

```ruby
add_index :meetings, [:user_id, :starts_at, :ends_at]
```

For unscoped validation, index the range columns alone (`[:starts_at, :ends_at]`). If you added the PostgreSQL exclusion constraint, you already have a suitable index — the constraint is backed by a GiST index that serves overlap queries. On large tables, verify with `EXPLAIN` that the query actually uses your index.

## Ruby / Rails Compatibility

Every combination below is verified on every push by the [CI matrix](https://github.com/tilo/validates_overlap/actions):

| Rails | Tested with Ruby   |
|-------|--------------------|
| 8.1   | 3.2, 3.3, 3.4      |
| 8.0   | 3.2, 3.3, 3.4      |
| 7.2   | 3.1, 3.2, 3.3, 3.4 |
| 7.1   | 3.0, 3.1, 3.2, 3.3 |
| 7.0   | 3.0, 3.1, 3.2      |
| 6.1   | 3.0                |

The gemspec requires `activerecord >= 6.0`. Rails 6.0 is not part of the test matrix, but no incompatibilities are known. The previous version 0.8.6 was compatible with Rails 3, 4, and 5.

Note for MySQL users: use `DATETIME` (not `TIMESTAMP`) columns for your range attributes — MySQL's `TIMESTAMP` type cannot store dates after January 2038, which matters for long-running or far-future ranges. PostgreSQL and SQLite date/time types have no such limit.

## Contributing

Bug reports and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the test suite against all three database adapters (SQLite, PostgreSQL, MySQL).

## Maintainership

`validates_overlap` was created by [Robin Bortlik](https://github.com/robinbortlik), who built and maintained it starting 2011.
Since August 2026 the gem is maintained by [Tilo Sloboda](https://github.com/tilo).

A big thank you to Robin for creating this awesome gem and for the years of work he put into it. ❤️
