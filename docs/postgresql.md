### Contents

  * [Examples and Introduction](./_introduction.md)
  * [Option Reference](./options.md)
  * [Range Types and Domains](./range_types.md)
  * [**PostgreSQL: Exclusion Constraints**](./postgresql.md)

--------------

# PostgreSQL: Exclusion Constraints

How to make the no-overlap guarantee hold at the database level — the part no validation can do.

## ⚠️ Validation alone can NOT prevent double-booking under concurrent writes

Like Rails' `validates_uniqueness_of`, this validation is a check followed by a separate insert: two concurrent requests can BOTH run the overlap check, BOTH see no conflict, and BOTH save. No application-level validation can close that race — the validation exists to give users friendly error messages, not to guarantee correctness under concurrent writes.

For a hard guarantee, add a database-level exclusion constraint (PostgreSQL). Since 1.3.0 the gem ships migration helpers that generate it — the range type is inferred from your column types, and the options mirror the validator's:

```ruby
class AddOverlapConstraintToMeetings < ActiveRecord::Migration[7.1]
  def up
    add_overlap_constraint :meetings, :starts_at, :ends_at, scope: :user_id
  end

  def down
    remove_overlap_constraint :meetings
  end
end
```

Helper options:

| Option          | Default              | Effect                                                                                                                                                         |
|-----------------|----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `scope`         | none                 | Column(s) compared with equality, mirroring the validator's `scope`                                                                                            |
| `name`          | `<table>_no_overlap` | The constraint name — pass the same `name:` to `remove_overlap_constraint` when overridden                                                                     |
| `range_type`    | inferred             | PostgreSQL range type; inferred from the column types (`tsrange`, `tstzrange`, `daterange`, `int4range`, `int8range`, `numrange`)                              |
| `exclude_edges` | `false`              | `false` = inclusive edges, touching conflicts (the validator's default); `true` = half-open ranges, touching allowed. Not applicable to the single-column form |

## Turning the violation into a validation error

To turn the constraint violation from the race window into a normal validation failure (instead of an exception bubbling up), include the companion concern in your model — `save` then returns false with the overlap error set, and `save!` raises `ActiveRecord::RecordInvalid`:

```ruby
class Meeting < ActiveRecord::Base
  validates :starts_at, :ends_at, overlap: { scope: :user_id }
  include ValidatesOverlap::RescueExclusionViolation
end
```

## Native range columns

PostgreSQL can store a range as a single column value (`tsrange`, `tstzrange`, `daterange`, `int4range`, `int8range`, `numrange`). Declare the validation with that one attribute:

```ruby
# migration
create_table :meetings do |t|
  t.tstzrange :period
  t.integer :user_id
end

# model — one attribute instead of two
class Meeting < ActiveRecord::Base
  validates :period, overlap: { scope: :user_id }
end

Meeting.create!(user_id: 1, period: Time.utc(2030, 1, 1, 10)...Time.utc(2030, 1, 1, 12))
Meeting.new(user_id: 1, period: Time.utc(2030, 1, 1, 11)...Time.utc(2030, 1, 1, 13)).valid?  # => false (overlaps)
Meeting.new(user_id: 1, period: Time.utc(2030, 1, 1, 12)...Time.utc(2030, 1, 1, 14)).valid?  # => true (half-open ranges may touch)
Meeting.new(user_id: 1, period: nil).valid?                                                  # => true (no range, conflicts with nothing)
```

The comparison uses PostgreSQL's `&&` operator, and PostgreSQL's own range algebra decides every edge case — which means the validation and an exclusion constraint can never disagree:

- bound inclusivity is part of the stored value: a half-open `[10:00,12:00)` may touch the next range, a closed `[10:00,12:00]` conflicts with it — there is no `exclude_edges` option to configure
- a `NULL` column means no range and conflicts with nothing; "spans everything" is spelled explicitly as the unbounded range `'(,)'`
- the `empty` range conflicts with nothing
- `exclude_edges`, `start_shift`, and `end_shift` raise `ArgumentError` for a range column — they have nothing to act on
- a single-attribute validation on a non-range column raises `OverlapValidator::UnsupportedColumnType` at validate time

All other options work unchanged (`scope`, `scoped_model`, `query_options`, custom messages), as do `overlapping_records` and `ValidatesOverlap::RescueExclusionViolation`. The constraint helper accepts the same single-column form:

```ruby
add_overlap_constraint :meetings, :period, scope: :user_id
```

## What the helper generates

The generated constraint is equivalent to this hand-written migration:

```ruby
class AddOverlapConstraintToMeetings < ActiveRecord::Migration[7.1]
  def up
    enable_extension 'btree_gist'   # needed to mix scalar columns (=) with ranges (&&)
    execute <<~SQL
      ALTER TABLE meetings
        ADD CONSTRAINT meetings_no_overlap
        EXCLUDE USING gist (
          user_id WITH =,
          tsrange(starts_at, ends_at, '[]') WITH &&
        )
    SQL
  end

  def down
    execute 'ALTER TABLE meetings DROP CONSTRAINT meetings_no_overlap'
  end
end
```

How the pieces map to this gem's options:

- `user_id WITH =` mirrors `scope:` — records only conflict within the same scope; add one `WITH =` line per scope column, or omit for unscoped validation.
- `tsrange(starts_at, ends_at, '[]')` treats a `NULL` start or end as open-ended — the same semantics as this gem. The `'[]'` makes both edges inclusive, matching the gem's default where touching edges conflict; use the default `'[)'` bounds to match `exclude_edges: 'ends_at'`. Use `tstzrange` for timezone-aware columns, `daterange` for dates, `int4range` / `numrange` for numeric ranges.
- When the constraint fires, ActiveRecord raises `ActiveRecord::StatementInvalid` (wrapping `PG::ExclusionViolation`) — rescue it around the save and treat it like a failed validation.
- MySQL and SQLite have no exclusion constraints; there the validation is best-effort, exactly like `validates_uniqueness_of` without a unique index.

Keep the validation even with the constraint in place: the validator produces friendly per-attribute error messages for the normal case, and the constraint catches the rare race the validator cannot.

----------------

PREVIOUS: [Range Types and Domains](./range_types.md) | UP: [README](../README.md)
