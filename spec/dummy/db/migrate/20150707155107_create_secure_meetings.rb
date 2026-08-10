class CreateSecureMeetings < ActiveRecord::Migration[6.0]
  def self.up
    # string primary key (UUID-style) — SecureMeeting exists to test PK exclusion with string ids
    create_table :secure_meetings, id: :string do |t|
      t.date :starts_at
      t.date :ends_at
      t.timestamps
    end
  end

  def self.down
    drop_table :secure_meetings
  end
end
