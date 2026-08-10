# Exists ONLY to assert that the validator REJECTS :time range columns —
# time-of-day is a cyclic domain, fundamentally incompatible with overlap
# validation (see the README note)
class DailyWindow < ActiveRecord::Base
  validates :starts_at, :ends_at, overlap: true
end
