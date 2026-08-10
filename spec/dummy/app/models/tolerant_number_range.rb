# Range-SHRINKING integer shifts: up to 10 numbers of overlap are tolerated
class TolerantNumberRange < ActiveRecord::Base
  self.table_name = 'number_ranges'
  validates :range_start, :range_end, overlap: { start_shift: 10, end_shift: -10 }
end
