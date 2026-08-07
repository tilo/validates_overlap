# Exercises the validator's state isolation (issue #50): the scope proc runs in
# the middle of building one record's overlap query, so a hook here can trigger
# another validation of the same class at exactly that point
class ReentrantMeeting < ActiveRecord::Base
  self.table_name = 'user_meetings'

  attr_accessor :during_scope_resolution

  validates :starts_at, :ends_at, overlap: {
    scope: { 'user_id' => proc { |record| record.during_scope_resolution&.call; record.user_id } }
  }
end
