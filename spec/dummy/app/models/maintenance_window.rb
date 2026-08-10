# TIMESTAMP range columns (t.timestamp — the adapter's TIMESTAMP type)
class MaintenanceWindow < ActiveRecord::Base
  validates :starts_at, :ends_at, overlap: true
end
