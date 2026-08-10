# DECIMAL range columns (e.g. price bands)
class PriceBand < ActiveRecord::Base
  validates :range_start, :range_end, overlap: true
end
