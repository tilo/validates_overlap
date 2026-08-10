# Range-SHRINKING shifts: tolerate up to 2 days of overlap between shifts
# (the Shift model covers the opposite, range-widening direction: a required gap)
class TolerantShift < ActiveRecord::Base
  self.table_name = 'shifts'
  validates :starts_at, :ends_at, overlap: { start_shift: 2.days, end_shift: -2.days }
end
