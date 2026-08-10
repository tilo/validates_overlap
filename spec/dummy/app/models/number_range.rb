# The overlap check works on any orderable column type, not just dates/times —
# this model covers INTEGER ranges (e.g. ticket number blocks)
class NumberRange < ActiveRecord::Base
  validates :range_start, :range_end, overlap: true
end
