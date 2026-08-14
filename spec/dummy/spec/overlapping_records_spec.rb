require 'spec_helper'

# record.overlapping_records — defined on every model that declares an overlap
# validation; freshly queries the conflicting records and returns a Relation
describe 'overlapping_records' do
  it 'is defined on models with an overlap validation, not on others' do
    expect(Meeting.new).to respond_to(:overlapping_records)
    expect(User.new).not_to respond_to(:overlapping_records)
  end

  it 'returns an ActiveRecord::Relation' do
    expect(Meeting.new.overlapping_records).to be_a(ActiveRecord::Relation)
  end

  it 'returns the conflicting records, freshly computed on every call' do
    existing = FactoryBot.create(:meeting)
    meeting = FactoryBot.build(:meeting, starts_at: '2011-01-06'.to_date, ends_at: '2011-01-07'.to_date)
    expect(meeting.overlapping_records).to eq [existing]

    meeting.starts_at = '2011-02-01'.to_date
    meeting.ends_at = '2011-02-02'.to_date
    expect(meeting.overlapping_records).to be_empty
  end

  it 'respects the scope option' do
    johns = FactoryBot.create(:johns_meeting)
    expect(FactoryBot.build(:johns_meeting).overlapping_records).to eq [johns]
    expect(FactoryBot.build(:peters_meeting).overlapping_records).to be_empty
  end

  it 'does not include the record itself once persisted' do
    meeting = FactoryBot.create(:meeting)
    expect(meeting.overlapping_records).to be_empty
  end

  it 'works without the deprecated load_overlapped option' do
    expect(UserMeeting.new).to respond_to(:overlapping_records)
  end

  it 'allows counting without loading records' do
    FactoryBot.create(:meeting)
    meeting = FactoryBot.build(:meeting, starts_at: '2011-01-06'.to_date, ends_at: '2011-01-07'.to_date)
    expect(meeting.overlapping_records.count).to eq 1
  end

  it 'still returns a Relation when the validators were removed (clear_validators!)' do
    stub_const('StrippedMeeting', Class.new(Meeting))
    StrippedMeeting.clear_validators!
    record = StrippedMeeting.new
    expect(record.overlapping_records).to be_a(ActiveRecord::Relation)
    expect(record.overlapping_records).to be_empty
  end

  # Relation#or never compares the two relations' classes — without this guard
  # the union would silently run the second validation's conditions against the
  # first validation's model
  it 'raises a clear error when overlap validations query different models' do
    stub_const('DualModelMeeting', Class.new(ActiveRecord::Base) do
      self.table_name = 'meetings'
      validates :starts_at, :ends_at, overlap: true
      validates :starts_at, :ends_at, overlap: { scoped_model: 'MeetingCopy' }
    end)
    record = DualModelMeeting.new(starts_at: '2011-01-06'.to_date, ends_at: '2011-01-07'.to_date)
    expect { record.overlapping_records }.to raise_error(ArgumentError, /different models/)
  end
end
