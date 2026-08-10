require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe LiteralScopedMeeting do
  context 'Validation with a literal (non-Proc) scope value' do
    before do
      LiteralScopedMeeting.create!(user_id: 1, starts_at: '2011-01-05'.to_date, ends_at: '2011-01-08'.to_date)
    end

    it 'is not valid if it overlaps a meeting of the literally scoped user — even from another user' do
      meeting = LiteralScopedMeeting.new(user_id: 2, starts_at: '2011-01-06'.to_date, ends_at: '2011-01-07'.to_date)
      expect(meeting).not_to be_valid
      expect(meeting.errors[:starts_at]).not_to be_empty
    end

    it 'is valid if it does not overlap any meeting of the literally scoped user' do
      meeting = LiteralScopedMeeting.new(user_id: 2, starts_at: '2011-02-01'.to_date, ends_at: '2011-02-02'.to_date)
      expect(meeting).to be_valid
      expect(meeting.errors[:starts_at]).to be_empty
    end
  end
end
