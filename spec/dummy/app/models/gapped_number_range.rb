# Range-WIDENING integer shifts: number blocks must be at least 10 apart
# (shift arithmetic is plain Ruby +, so it is type-sensitive — this covers integers)
class GappedNumberRange < ActiveRecord::Base
  self.table_name = 'number_ranges'
  validates :range_start, :range_end, overlap: { start_shift: -10, end_shift: 10 }
end
