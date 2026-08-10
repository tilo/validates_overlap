# The overlap check works on any orderable column type, not just dates/times —
# this model covers STRING ranges (e.g. alphabetical name partitions)
class NameRange < ActiveRecord::Base
  validates :range_start, :range_end, overlap: true
end
