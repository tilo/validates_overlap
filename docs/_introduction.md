### Contents

  * [**Examples and Introduction**](./_introduction.md)
  * [Option Reference](./options.md)
  * [Range Types and Domains](./range_types.md)
  * [PostgreSQL: Exclusion Constraints](./postgresql.md)

--------------

# ValidatesOverlap Introduction

`validates_overlap` provides an ActiveRecord validator for resources that must not overlap, e.g. in datetime. Think rentals, meetings, bookings, work shifts, or assignments where the same resource cannot be assigned to multiple people or entities during overlapping time periods.

You specify the attributes defining a range — typically two, such as `starts_at` and `ends_at`, or on PostgreSQL a single native range column — and the validator checks with a single SQL query whether another record overlaps that range. If one does, the record receives a normal validation error.

The [Option Reference](./options.md) defines every option. [Range Types and Domains](./range_types.md) explains which column types work — and why cyclic domains fundamentally cannot. [PostgreSQL: Exclusion Constraints](./postgresql.md) shows how to make the no-overlap guarantee hold under concurrent writes, which no validation alone can do.

## Basic Examples

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

#### define custom validation key(s) and message

```ruby
validates :starts_at, :ends_at, :overlap => {:message_title => "Some validation title", :message_content => "Some validation message"}
validates :starts_at, :ends_at, :overlap => {:message_title => [:start_at, :end_at], :message_content => "Some validation message"}
```

## Advanced Examples

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

#### Overlapping records

If you need to know which records are in conflict, call `overlapping_records` — it is defined on every model with an overlap validation. It runs the query when called and returns an `ActiveRecord::Relation`, so no records are loaded until you use the result:

```ruby
meeting = Meeting.new(starts_at: '2026-09-01', ends_at: '2026-09-03')
meeting.overlapping_records          # => the conflicting meetings
meeting.overlapping_records.count    # => runs a COUNT query, loads no records
```

The former mechanism — `overlap: { load_overlapped: true }`, which set `@overlapped_records` on the record and required a hand-written accessor — still works but is deprecated and will be removed in 2.0: it kept stale results after re-validation and loaded the records during every validation.

#### PostgreSQL range columns and exclusion constraints

On PostgreSQL, the range can live in a single native range column, and a database-level exclusion constraint can close the concurrency race no validation can — examples for both are on the [PostgreSQL: Exclusion Constraints](./postgresql.md) page.

#### skipping validation when no range is set

The standard Rails `if:` / `unless:` options work as with any validation. For example, to skip the overlap check when a record has no range at all (by default, a record with both endpoints nil counts as spanning all time and conflicts with everything):

```ruby
validates :starts_at, :ends_at, overlap: true, if: -> { starts_at.present? || ends_at.present? }
```

Note: `allow_nil` and `allow_blank` do NOT work with this validator — use `if:` / `unless:` instead.

#### catching inverted ranges

The validator does not check that `start <= end`. To catch accidentally swapped endpoints loudly, pair the overlap validation with an order check:

```ruby
validates :ends_at, comparison: { greater_than: :starts_at }
```

----------------

NEXT: [Option Reference](./options.md) | UP: [README](../README.md)
