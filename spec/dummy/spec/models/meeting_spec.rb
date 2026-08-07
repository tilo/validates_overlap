require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe Meeting do
  context 'Validation' do
    it 'create meeting' do
      expect do
        FactoryBot.create(:meeting)
      end.to change(Meeting, :count).by(1)
    end

    context 'simple validation' do
      let!(:existing_meeting) { FactoryBot.create(:meeting) }

      OVERLAP_TIME_RANGES.each do |description, time_range|
        it "is not valid if exists meeting which #{description}" do
          meeting = FactoryBot.build(:meeting, starts_at: time_range.first, ends_at: time_range.last)
          expect(meeting).not_to be_valid
          expect(meeting.errors[:starts_at]).not_to be_empty
          expect(meeting.errors[:ends_at]).to be_empty
        end
      end

      it 'validate object which has not got overlap' do
        meeting = FactoryBot.build(:meeting, starts_at: '2011-01-09'.to_date, ends_at: '2011-01-11'.to_date)
        expect(meeting).to be_valid
        expect(meeting.errors[:starts_at]).to be_empty
        expect(meeting.errors[:ends_at]).to be_empty

        meeting = FactoryBot.build(:meeting, starts_at: '2011-01-01'.to_date, ends_at: '2011-01-02'.to_date)
        expect(meeting).to be_valid
        expect(meeting.errors[:starts_at]).to be_empty
        expect(meeting.errors[:ends_at]).to be_empty
      end

      describe '@overlapped_records' do
        it 'store the overlapped records' do
          meeting = FactoryBot.build(:meeting, starts_at: '2011-01-05'.to_date, ends_at: '2011-01-08'.to_date)
          expect(meeting).not_to be_valid
          expect(meeting.instance_variable_get(:@overlapped_records)).to eq [existing_meeting]
        end
      end
    end


    context 'Validation of endless objects' do
      xit 'with overlap object' do
        FactoryBot.create(:meeting)
        meeting = FactoryBot.build(:meeting, starts_at: '2011-01-05'.to_date, ends_at: '2011-01-08'.to_date)
        expect(meeting).not_to be_valid
        meeting = FactoryBot.build(:meeting, starts_at: '2012-01-05'.to_date, ends_at: '2012-01-08'.to_date)
        expect(meeting).not_to be_valid
        meeting = FactoryBot.build(:meeting, starts_at: '2010-01-05'.to_date, ends_at: '2010-01-08'.to_date)
        expect(meeting).to be_valid
      end

      it 'with another endless object' do
        FactoryBot.create(:meeting)

        meeting = FactoryBot.build(:meeting, starts_at: '2010-01-05'.to_date, ends_at: nil)
        expect(meeting).not_to be_valid
        meeting = FactoryBot.build(:meeting, starts_at: nil, ends_at: '2010-01-05'.to_date)
        expect(meeting).to be_valid
        meeting = FactoryBot.build(:meeting, starts_at: nil, ends_at: nil)
        expect(meeting).not_to be_valid
      end
    end
  end
end
