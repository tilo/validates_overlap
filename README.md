# ValidatesOverlap

![Gem Version](https://img.shields.io/gem/v/validates_overlap) [![RSpec](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml/badge.svg)](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml) [![codecov](https://codecov.io/gh/tilo/validates_overlap/branch/main/graph/badge.svg)](https://app.codecov.io/gh/tilo/validates_overlap/tree/main) [![Downloads](https://img.shields.io/gem/dt/validates_overlap)](https://rubygems.org/gems/validates_overlap) [![RubyGems](https://img.shields.io/badge/RubyGems-validates__overlap-brightgreen?logo=rubygems&logoColor=white)](https://rubygems.org/gems/validates_overlap) [![Ruby Toolbox](https://img.shields.io/badge/Ruby%20Toolbox-validates__overlap-brightgreen)](https://www.ruby-toolbox.com/projects/validates_overlap)

`validates_overlap` provides an ActiveRecord validator for resources that must not overlap in time. Think rentals, meetings, bookings, work shifts, or assignments where the same resource cannot be assigned to multiple people or entities during overlapping time periods.

You specify two attributes defining a time range, such as `starts_at` and `ends_at`, and the validator checks with a single SQL query whether another record overlaps that range — no records are loaded for the comparison. If one does, the record receives a normal validation error.

It also supports scoped validation (per user, room, resource, etc.), open-ended ranges (a nil start or end counts as extending forever), ranges that may touch at their boundaries (`exclude_edges`), required gaps between ranges or a tolerated amount of overlap (`start_shift` / `end_shift`), associations, and retrieving the conflicting records.

The range columns don't have to be dates or times: any orderable column type works, such as integer ranges (ticket number blocks) or string ranges (alphabetical partitions).

## Compatibility

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

The overlap check runs on plain SQL comparisons, so any orderable column type works — for example integer ranges (no two records may claim overlapping number blocks) or string ranges (alphabetical partitions). A nil endpoint means the range is open-ended on that side, for these types too.

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

Example describes valildatation of user, positions and time slots.
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


