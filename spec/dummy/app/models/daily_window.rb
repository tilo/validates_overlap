# Pure TIME-of-day range columns (t.time — no date part, e.g. daily opening
# hours). NOTE: a window crossing midnight (22:00..02:00) cannot be expressed
# as a single time range — split it in two, or use datetime columns
class DailyWindow < ActiveRecord::Base
  validates :starts_at, :ends_at, overlap: true
end
