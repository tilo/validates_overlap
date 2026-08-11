# ValidatesOverlap

![Gem Version](https://img.shields.io/gem/v/validates_overlap) [![RSpec](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml/badge.svg)](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml) [![codecov](https://codecov.io/gh/tilo/validates_overlap/branch/main/graph/badge.svg)](https://app.codecov.io/gh/tilo/validates_overlap/tree/main) [![Downloads](https://img.shields.io/gem/dt/validates_overlap)](https://rubygems.org/gems/validates_overlap) [![RubyGems](https://img.shields.io/badge/RubyGems-validates__overlap-brightgreen?logo=rubygems&logoColor=white)](https://rubygems.org/gems/validates_overlap) [![Ruby Toolbox](https://img.shields.io/badge/Ruby%20Toolbox-validates__overlap-brightgreen)](https://www.ruby-toolbox.com/projects/validates_overlap)

`validates_overlap` provides an ActiveRecord validator for resources that must not overlap, e.g. in datetime. Think rentals, meetings, bookings, work shifts, or assignments where the same resource cannot be assigned to multiple people or entities during overlapping time periods. But it also works for other domains than datetime (see below).

You specify two attributes defining a datetime range, such as `starts_at` and `ends_at`, and the validator checks with a single SQL query whether another record overlaps that range — no records are loaded for the comparison. If one does, the record receives a normal validation error.

It also supports scoped validation (per user, room, resource, etc.), open-ended ranges (a nil start or end counts as extending forever), ranges that may touch at their boundaries (`exclude_edges`), required gaps between ranges or a tolerated amount of overlap (`start_shift` / `end_shift`), associations, and retrieving the conflicting records.

The range columns don't have to be dates or times: any linearly orderable column type works, such as integer ranges (ticket number blocks), decimal ranges (price bands), or string ranges (alphabetical partitions).

## Note: Other Domains

Other domains / types can be checked for overlap, as long as they can be compared linearly.
e.g. The overlap check runs on plain SQL comparisons, so any linearly orderable column type works — for example integer ranges (no two records may claim overlapping number blocks), decimal ranges (price bands), or string ranges (alphabetical partitions). A nil endpoint means the range is open-ended on that side, for these types too, and the shifts work for numeric ranges as well (e.g. an integer gap or overlap tolerance). The test suite covers `date`, `datetime`, `timestamp`, `integer`, `decimal`, and `string` range columns.

## ⚠️ Note: Cyclic Domains can NOT be validated for overlap

Overlap validation requires a linear domain: every range must satisfy `start <= end`. On a cyclic (wrap-around) domain, like time, every pair of values denotes *some* valid range (`11:00..10:00` is simply the 23-hour complement of `10:00..11:00`), so a wraparound range is indistinguishable from accidentally swapped fields — no validation can tell intent from typo. This is a mathematical property of circular domains, not an implementation gap.

The validator therefore refuses `:time` range columns and raises `OverlapValidator::UnsupportedColumnType` — use datetime columns instead, or split windows that cross midnight into two records.

But cyclicity is a property of the domain, not the column type — ⚠️ user-encoded cyclic domains hide inside perfectly linear columns, where no guard can see them:

- day-of-week as integer (0..6): a Friday-to-Monday shift range `5..1` wraps — same pathology as `22:00..02:00`, stored in an innocent `:integer` column
- month numbers (1..12): a November-to-February season range `11..2`
- ISO week numbers: a range from week 52 to week 2 across New Year
- angles / compass headings (0..360): a heading sector `350..10`
- longitude (−180°..+180°)
- hour-of-day as integer — people re-implement `:time` in an int column all the time
- time-of-day (24-hour clock values without a date component)

If your domain is cyclic, the validator will silently give wrong answers for wrapping ranges. Restructure the data instead: split wrapping ranges into two linear records, or lift the values into a linear domain (e.g. datetime instead of time-of-day).

To catch inverted ranges loudly instead of silently (for any column type), pair the overlap validation with an order check on your model, e.g. `validates :ends_at, comparison: { greater_than: :starts_at }`.

## ⚠️ Note: Validation alone can NOT prevent double-booking under concurrent writes

Like Rails' `validates_uniqueness_of`, this validation is a check followed by a separate insert: two concurrent requests can BOTH run the overlap check, BOTH see no conflict, and BOTH save. No application-level validation can close that race — the validation exists to give users friendly error messages, not to guarantee correctness under concurrent writes.

For a hard guarantee, add a database-level exclusion constraint (PostgreSQL):

```ruby
class AddOverlapConstraintToMeetings < ActiveRecord::Migration[7.1]
  def up
    enable_extension 'btree_gist'   # needed to mix scalar columns (=) with ranges (&&)
    execute <<~SQL
      ALTER TABLE meetings
        ADD CONSTRAINT no_overlapping_meetings
        EXCLUDE USING gist (
          user_id WITH =,
          tsrange(starts_at, ends_at, '[]') WITH &&
        )
    SQL
  end

  def down
    execute 'ALTER TABLE meetings DROP CONSTRAINT no_overlapping_meetings'
  end
end
```

How the pieces map to this gem's options:

- `user_id WITH =` mirrors `scope:` — records only conflict within the same scope; add one `WITH =` line per scope column, or omit for unscoped validation.
- `tsrange(starts_at, ends_at, '[]')` treats a `NULL` start or end as open-ended — the same semantics as this gem. The `'[]'` makes both edges inclusive, matching the gem's default where touching edges conflict; use the default `'[)'` bounds to match `exclude_edges: 'ends_at'`. Use `tstzrange` for timezone-aware columns, `daterange` for dates, `int4range` / `numrange` for numeric ranges.
- When the constraint fires, ActiveRecord raises `ActiveRecord::StatementInvalid` (wrapping `PG::ExclusionViolation`) — rescue it around the save and treat it like a failed validation.
- MySQL and SQLite have no exclusion constraints; there the validation is best-effort, exactly like `validates_uniqueness_of` without a unique index.

Keep the validation even with the constraint in place: the validator produces friendly per-attribute error messages for the normal case, and the constraint catches the rare race the validator cannot.

## Note: Add an index — the overlap check runs on every save

The validation runs one `EXISTS` query per save. Without a suitable index that query is a full table scan — invisible at 1,000 rows, painful at 1,000,000. Add a composite index with your scope columns first, then the range columns:

```ruby
add_index :meetings, [:user_id, :starts_at, :ends_at]
```

For unscoped validation, index the range columns alone (`[:starts_at, :ends_at]`). If you added the PostgreSQL exclusion constraint from the section above, you already have a suitable index — the constraint is backed by a GiST index that serves overlap queries. On large tables, verify with `EXPLAIN` that the query actually uses your index.

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

## Usage

Add to your gemfile

```ruby
gem 'validates_overlap'
```

In your model

#### without scope

```ruby
validates :starts_at, :ends_at, :overlap => true
```

#### with scope

```ruby
validates :starts_at, :ends_at, :overlap => {:scope => "user_id"}
```

#### exclude edge(s)

```ruby
validates :starts_at, :ends_at, :overlap => {:exclude_edges => "starts_at"}
validates :starts_at, :ends_at, :overlap => {:exclude_edges => ["starts_at", "ends_at"]}
```

#### shift edges

The shifts move the record's own range edges before the overlap check, so you can require a gap between records — or tolerate a bounded overlap:

```ruby
# widen the range: records must be at least 1 day apart (gap enforced)
validates :starts_at, :ends_at, :overlap => {:start_shift => -1.day, :end_shift => 1.day}

# shrink the range: up to 2 days of overlap are accepted
validates :starts_at, :ends_at, :overlap => {:start_shift => 2.days, :end_shift => -2.days}
```

#### non-date ranges

The overlap check runs on plain SQL comparisons, so any orderable column type works — for example integer ranges (no two records may claim overlapping number blocks), decimal ranges (price bands), or string ranges (alphabetical partitions). A nil endpoint means the range is open-ended on that side, for these types too, and the shifts work for numeric ranges as well (e.g. an integer gap or overlap tolerance). The test suite covers `date`, `datetime`, `timestamp`, `integer`, `decimal`, and `string` range columns.

```ruby
class TicketBlock < ActiveRecord::Base
  validates :number_start, :number_end, :overlap => true
end

TicketBlock.create!(number_start: 100, number_end: 199)
TicketBlock.new(number_start: 150, number_end: 250).valid?  # => false (overlaps)
TicketBlock.new(number_start: 150, number_end: nil).valid?  # => false (open-ended, overlaps)
TicketBlock.new(number_start: 200, number_end: 299).valid?  # => true
```

#### define custom validation key(s) and message

```ruby
validates :starts_at, :ends_at, :overlap => {:message_title => "Some validation title", :message_content => "Some validation message"}
validates :starts_at, :ends_at, :overlap => {:message_title => [:start_at, :end_at], :message_content => "Some validation message"}
```

#### with complicated relations

Example describes validation of user, positions and time slots.
User can't be assigned 2 times on position which is under time slot with time overlap.

```ruby
class Position < ActiveRecord::Base
  belongs_to :time_slot
  belongs_to :user
  validates "time_slots.starts_at", "time_slots.ends_at",
    :overlap => {
      :query_options => {:joins => :time_slot},
      :scope => { "positions.user_id" => proc{|position| position.user_id} }
    }
end
```

#### apply named scopes

```ruby
class ActiveMeeting < ActiveRecord::Base
  validates :starts_at, :ends_at, :overlap => {:query_options => {:active => nil}}
  scope :active, where(:is_active => true)
end
```

#### Overlapped records
If you need to know what records are in conflict, pass the `{load_overlapped: true }` as validator option and validator will set instance variable `@overlapped_records` to the validated object.

```ruby
class ActiveMeeting < ActiveRecord::Base
  validates :starts_at, :ends_at, :overlap => {:load_overlapped => true}

  def overlapped_records
    @overlapped_records || []
  end
end

```

## Maintainership

`validates_overlap` was created by [Robin Bortlik](https://github.com/robinbortlik), who built and maintained it starting 2011.
Since August 2026 the gem is maintained by [Tilo Sloboda](https://github.com/tilo).

A big thank you to Robin for creating this awesome gem and for the years of work he put into it. ❤️


