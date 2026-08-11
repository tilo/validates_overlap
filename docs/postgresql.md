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

## Turning the violation into a validation error

To turn the constraint violation from the race window into a normal validation failure (instead of an exception bubbling up), include the companion concern in your model — `save` then returns false with the overlap error set, and `save!` raises `ActiveRecord::RecordInvalid`:

```ruby
class Meeting < ActiveRecord::Base
  validates :starts_at, :ends_at, overlap: { scope: :user_id }
  include ValidatesOverlap::RescueExclusionViolation
end
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
