require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe MeetingCopy do
  context 'Validation with the :scoped_model option' do
    before do
      FactoryBot.create(:meeting)
    end

    it 'is not valid if a record of the scoped model overlaps' do
      meeting = MeetingCopy.new(starts_at: '2011-01-06'.to_date, ends_at: '2011-01-07'.to_date)
      expect(meeting).not_to be_valid
      expect(meeting.errors[:starts_at]).not_to be_empty
    end

    it 'is valid if no record of the scoped model overlaps' do
      meeting = MeetingCopy.new(starts_at: '2011-02-01'.to_date, ends_at: '2011-02-02'.to_date)
      expect(meeting).to be_valid
      expect(meeting.errors[:starts_at]).to be_empty
    end
  end
end
