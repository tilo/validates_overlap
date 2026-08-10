require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe SecureMeeting do
  context 'A model with a UUID as a primary key' do
    it 'updates the relevant record' do
      securemeeting = FactoryBot.create(:secure_meeting)
      securemeeting.starts_at = '2012-01-05'.to_date
      securemeeting.ends_at = '2012-02-05'.to_date
      expect(securemeeting).to be_valid
      expect(securemeeting.errors[:starts_at]).to be_empty
      expect(securemeeting.errors[:ends_at]).to be_empty
    end

    it 'is not valid if it overlaps a persisted record with a UUID key' do
      FactoryBot.create(:secure_meeting)
      meeting = FactoryBot.build(:secure_meeting, starts_at: '2010-11-06'.to_date, ends_at: '2010-11-07'.to_date)
      expect(meeting).not_to be_valid
      expect(meeting.errors[:starts_at]).not_to be_empty
    end

    it 'excludes itself by primary key even if the key contains a quote' do
      securemeeting = FactoryBot.create(:secure_meeting, id: "o'brien-#{SecureRandom.uuid}")
      securemeeting.starts_at = '2012-01-05'.to_date
      securemeeting.ends_at = '2012-02-05'.to_date
      expect(securemeeting).to be_valid
    end
  end
end
