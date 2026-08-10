# Validates against Meeting's records via :scoped_model. Its own default scope
# hides every row, so a conflict can only be found through the scoped model —
# which is exactly what this model exists to prove.
class MeetingCopy < ActiveRecord::Base
  self.table_name = 'meetings'
  default_scope { where('1 = 0') }

  validates :starts_at, :ends_at, overlap: { scoped_model: 'Meeting' }
end
