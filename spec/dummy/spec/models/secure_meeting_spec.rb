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
  end
end
