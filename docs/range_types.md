### Contents

  * [Examples and Introduction](./_introduction.md)
  * [Option Reference](./options.md)
  * [**Range Types and Domains**](./range_types.md)
  * [PostgreSQL: Exclusion Constraints](./postgresql.md)

--------------

# Range Types and Domains

Which column types the overlap validation works with — and which domains it fundamentally cannot support.

## Other Domains

Other domains / types can be checked for overlap, as long as they can be compared linearly.
e.g. The overlap check runs on plain SQL comparisons, so any linearly orderable column type works — for example integer ranges (no two records may claim overlapping number blocks), decimal ranges (price bands), or string ranges (alphabetical partitions). A nil endpoint means the range is open-ended on that side, for these types too, and the shifts work for numeric ranges as well (e.g. an integer gap or overlap tolerance). The test suite covers `date`, `datetime`, `timestamp`, `integer`, `decimal`, and `string` range columns.

```ruby
class TicketBlock < ActiveRecord::Base
  validates :number_start, :number_end, :overlap => true
end

TicketBlock.create!(number_start: 100, number_end: 199)
TicketBlock.new(number_start: 150, number_end: 250).valid?  # => false (overlaps)
TicketBlock.new(number_start: 150, number_end: nil).valid?  # => false (open-ended, overlaps)
TicketBlock.new(number_start: 200, number_end: 299).valid?  # => true
```

On PostgreSQL, a range can also be stored in a single native range column (`tstzrange`, `daterange`, `int4range`, …) and validated with one attribute — see [PostgreSQL: Exclusion Constraints](./postgresql.md). The test suite covers native range columns of timestamp, date, and integer subtypes there.

## ⚠️ Cyclic Domains can NOT be validated for overlap

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

PostgreSQL's native range types enforce the same rule at the data layer: a range whose start exceeds its end is rejected by the database itself (`range lower bound must be less than or equal to range upper bound`) — there is no wraparound range on a linear type, in this gem or in PostgreSQL.

To catch inverted ranges loudly instead of silently (for any column type), pair the overlap validation with an order check on your model, e.g. `validates :ends_at, comparison: { greater_than: :starts_at }`.

----------------

PREVIOUS: [Option Reference](./options.md) | NEXT: [PostgreSQL: Exclusion Constraints](./postgresql.md) | UP: [README](../README.md)
