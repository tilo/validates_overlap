require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe UserMeeting do
  it 'create johns meeting' do
    expect do
      FactoryBot.create(:johns_meeting)
    end.to change(UserMeeting, :count).by(1)
  end

  context 'Validation with scope' do
    before do
      FactoryBot.create(:johns_meeting)
    end

    OVERLAP_TIME_RANGES.each do |description, time_range|
      it "is not valid if exists johns meeting which #{description}" do
        meeting = FactoryBot.build(:johns_meeting, starts_at: time_range.first, ends_at: time_range.last)
        expect(UserMeeting.count).to eq 1
        expect(meeting).not_to be_valid
        expect(meeting.errors[:starts_at]).not_to be_empty
        expect(meeting.errors[:ends_at]).to be_empty
      end
    end

    OVERLAP_TIME_RANGES.each do |description, time_range|
      it "is valid if exists johns meeting which #{description}" do
        meeting = FactoryBot.build(:peters_meeting, starts_at: time_range.first, ends_at: time_range.last)
        expect(meeting).to be_valid
        expect(meeting.errors[:starts_at]).to be_empty
        expect(meeting.errors[:ends_at]).to be_empty
      end
    end
  end
end
