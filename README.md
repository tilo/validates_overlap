# ValidatesOverlap

![Gem Version](https://img.shields.io/gem/v/validates_overlap) [![Ruby](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml/badge.svg)](https://github.com/tilo/validates_overlap/actions/workflows/ruby.yml) [![codecov](https://codecov.io/gh/tilo/validates_overlap/branch/main/graph/badge.svg)](https://codecov.io/gh/tilo/validates_overlap) [![Downloads](https://img.shields.io/gem/dt/validates_overlap)](https://rubygems.org/gems/validates_overlap) [![RubyGems](https://img.shields.io/badge/RubyGems-validates__overlap-brightgreen?logo=rubygems&logoColor=white)](https://rubygems.org/gems/validates_overlap) [![Ruby Toolbox](https://img.shields.io/badge/Ruby%20Toolbox-validates__overlap-brightgreen)](https://www.ruby-toolbox.com/projects/validates_overlap)

`validates_overlap` adds an overlap validation to ActiveRecord models.
Ideal solution for booking applications where you want to make sure, that one place can be booked only once in specific time period.

You name the two attributes that define a time range — for example starts_at and ends_at — and the validator checks with a single SQL query that no other record's range overlaps it. If one does, the record gets a normal validation error.

Typical uses: bookings, reservations, meetings, work shifts, rentals — anywhere a resource must not be double-booked for the same period.

The check runs entirely in the database, so no records are loaded to compare against. It supports scoping the comparison (per user, per room, …), open-ended ranges (a nil start or end counts as extending forever), ranges that may touch at the edges, required gaps between ranges, validating through associations, and loading the conflicting records when you want to show them to the user.

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

```ruby
validates :starts_at, :ends_at, :overlap => {:start_shift => -1.day, :end_shift => 1.day}
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


