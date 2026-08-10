# DATETIME range columns — overlap at time-of-day precision, not whole days
class Appointment < ActiveRecord::Base
  validates :starts_at, :ends_at, overlap: true
end
