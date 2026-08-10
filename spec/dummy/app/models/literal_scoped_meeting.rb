# The scope value is a literal (not a Proc): every record is validated against
# user 1's meetings, regardless of its own user_id
class LiteralScopedMeeting < ActiveRecord::Base
  self.table_name = 'user_meetings'

  validates :starts_at, :ends_at, overlap: { scope: { 'user_id' => 1 } }
end
