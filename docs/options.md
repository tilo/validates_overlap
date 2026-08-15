### Contents

  * [Examples and Introduction](./_introduction.md)
  * [**Option Reference**](./options.md)
  * [Range Types and Domains](./range_types.md)
  * [PostgreSQL: Exclusion Constraints](./postgresql.md)

--------------

# Option Reference

The validation is declared with the two attributes that define the range, plus an options hash — or, on PostgreSQL, with a single [native range column](./postgresql.md) attribute:

```ruby
validates :starts_at, :ends_at, overlap: { <options> }
validates :period, overlap: { <options> }    # PostgreSQL range column (tstzrange etc.)
```

Attribute names may be plain column names, or `"table_name.column_name"` strings when validating through an association (combined with `query_options` for the join). Usage examples for every option are on the [Introduction](./_introduction.md) page.

| Option            | Values                               | Default         | Effect                                                                                                                                                  |
|-------------------|--------------------------------------|-----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `scope`           | column name, array of names, or hash | none            | Records only conflict when their scope values match — e.g. per user or per room                                                                         |
| `exclude_edges`   | attribute name or array of names     | none            | Ranges may touch at the named edge(s); by default touching edges count as overlap                                                                       |
| `start_shift`     | duration or number                   | none            | Added to the record's start value before the comparison — negative values widen the range (enforce a gap), positive values shrink it (tolerate overlap) |
| `end_shift`       | duration or number                   | none            | Added to the record's end value before the comparison — positive values widen the range, negative values shrink it                                      |
| `message_title`   | symbol, string, or array of keys     | first attribute | Which error key(s) receive the validation error                                                                                                         |
| `message_content` | string or symbol                     | `:overlap`      | The error message; the default translates via i18n (`en`, `es`, `pt-BR`, `ru` included)                                                                 |
| `query_options`   | hash of `{method_name => arguments}` | none            | Methods called on the comparison query before it runs — named scopes, `joins:`, `includes:`; use `nil` as the argument for methods without one          |
| `scoped_model`    | class name as string                 | record's class  | Validate against another model's records — the named class is used for the comparison query                                                             |
| `load_overlapped` | `true`                               | off             | DEPRECATED, removal in 2.0 — stored the conflicting records in `@overlapped_records`; use `record.overlapping_records` instead                          |

## Notes

- **`scope` forms:** a string or symbol names a column whose value must match; an array names several columns; a hash maps a column name to an explicit value — a literal, or a proc receiving the record (`{ "positions.user_id" => proc { |position| position.user_id } }`). A nil scope value matches other records whose value is also NULL. An array value builds an `IN` condition.
- **Shift directions:** the shifts move the record's own range edges before the comparison. Widening the range (`start_shift: -1.day, end_shift: 1.day`) enforces a minimum gap between records; shrinking it (`start_shift: 2.days, end_shift: -2.days`) tolerates up to that amount of overlap. Shifts must be addable to the range values: durations for date/time columns, numbers for numeric columns.
- **Open-ended ranges:** a record whose start or end attribute is nil is treated as open-ended on that side; a record with both endpoints nil spans all time and conflicts with everything. See [Range Types and Domains](./range_types.md).
- **Standard Rails options:** `if:` and `unless:` work as with any validation. `allow_nil` and `allow_blank` do NOT work with this validator.
- **`overlapping_records`:** not an option — a method defined on every model with an overlap validation; returns an `ActiveRecord::Relation` of the conflicting records, freshly queried on every call.
- **Column types:** any linearly orderable column type works; `:time` columns raise `OverlapValidator::UnsupportedColumnType`. See [Range Types and Domains](./range_types.md).
- **Range columns (PostgreSQL):** with a single range-column attribute, `exclude_edges` and the shifts raise `ArgumentError` — bound inclusivity and shifting are part of the range value itself. See [PostgreSQL: Exclusion Constraints](./postgresql.md).

----------------

UP: [README](../README.md) | PREVIOUS: [Examples and Introduction](./_introduction.md) | NEXT: [Range Types and Domains](./range_types.md)
