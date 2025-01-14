require 'spec_helper'
require 'mongoid'

Mongoid.load!(File.expand_path('../../dummy/config/database.yml', __FILE__), :mongoid)

class MongoidMeeting
  include Mongoid::Document
  field :starts_at, type: Date
  field :ends_at, type: Date

  validates :starts_at, :ends_at, overlap: { load_overlapped: true }
end

describe MongoidMeeting do
  context 'Validation' do
    it 'create meeting' do
      expect do
        MongoidMeeting.create(starts_at: '2022-01-01'.to_date, ends_at: '2022-01-02'.to_date)
      end.to change(MongoidMeeting, :count).by(1)
    end

    context 'simple validation' do
      let!(:existing_meeting) { MongoidMeeting.create(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date) }

      OVERLAP_TIME_RANGES.each do |description, time_range|
        it "is not valid if exists meeting which #{description}" do
          meeting = MongoidMeeting.new(starts_at: time_range.first, ends_at: time_range.last)
          expect(meeting).not_to be_valid
          expect(meeting.errors[:starts_at]).not_to be_empty
          expect(meeting.errors[:ends_at]).to be_empty
        end
      end

      it 'validate object which has not got overlap' do
        meeting = MongoidMeeting.new(starts_at: '2022-01-09'.to_date, ends_at: '2022-01-11'.to_date)
        expect(meeting).to be_valid
        expect(meeting.errors[:starts_at]).to be_empty
        expect(meeting.errors[:ends_at]).to be_empty

        meeting = MongoidMeeting.new(starts_at: '2022-01-01'.to_date, ends_at: '2022-01-02'.to_date)
        expect(meeting).to be_valid
        expect(meeting.errors[:starts_at]).to be_empty
        expect(meeting.errors[:ends_at]).to be_empty
      end

      describe '@overlapped_records' do
        it 'store the overlapped records' do
          meeting = MongoidMeeting.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
          expect(meeting).not_to be_valid
          expect(meeting.instance_variable_get(:@overlapped_records)).to eq [existing_meeting]
        end
      end
    end

    context 'Validation of endless objects' do
      it 'with overlap object' do
        MongoidMeeting.create(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        meeting = MongoidMeeting.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        expect(meeting).not_to be_valid
        meeting = MongoidMeeting.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        expect(meeting).not_to be_valid
        meeting = MongoidMeeting.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        expect(meeting).to be_valid
      end

      it 'with another endless object' do
        MongoidMeeting.create(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)

        meeting = MongoidMeeting.new(starts_at: '2022-01-05'.to_date, ends_at: nil)
        expect(meeting).not_to be_valid
        meeting = MongoidMeeting.new(starts_at: nil, ends_at: '2022-01-05'.to_date)
        expect(meeting).to be_valid
        meeting = MongoidMeeting.new(starts_at: nil, ends_at: nil)
        expect(meeting).not_to be_valid
      end
    end
  end
end
