require "#{File.dirname(__FILE__)}/spec_helper"

# Adapter-independent unit tests of the range-column query builder: the column
# metadata is stubbed and the returned relation is never executed, so these run
# on every adapter. The behavior against real PostgreSQL range columns is
# covered by spec_pg/range_column_spec.rb.
describe 'range-column query building' do
  before do
    stub_const('StubbedRangeModel', Class.new(ActiveRecord::Base) do
      self.table_name = 'meetings'
      attr_accessor :period
      validates :period, overlap: true
    end)
    # let ActiveRecord build and cache its attribute defaults from the real
    # columns first — after that, columns_hash is only read by the validator's
    # column-type guard, which is the one reader this stub is meant for
    StubbedRangeModel.new
    allow(StubbedRangeModel).to receive(:columns_hash).and_return(
      'period' => double('column', name: 'period', type: :tstzrange)
    )
  end

  it 'returns an empty relation without touching the database for a NULL range' do
    record = StubbedRangeModel.new
    expect(record.overlapping_records).to be_a(ActiveRecord::Relation)
    expect(record.overlapping_records).to be_empty
  end

  it 'builds the overlap relation lazily — no query runs until the result is used' do
    record = StubbedRangeModel.new
    record.period = Time.utc(2030, 1, 1, 10)...Time.utc(2030, 1, 1, 12)
    expect(record.overlapping_records).to be_a(ActiveRecord::Relation)
  end

  it 'overlapping_records raises the same error as valid? for a non-range column' do
    stub_const('MisdeclaredModel', Class.new(Meeting) do
      validates :starts_at, overlap: true
    end)
    record = MisdeclaredModel.new
    expect { record.valid? }.to raise_error(OverlapValidator::UnsupportedColumnType)
    expect { record.overlapping_records }.to raise_error(OverlapValidator::UnsupportedColumnType)
  end

  it 'raises for a two-attribute validation on range columns instead of running the scalar comparison' do
    stub_const('TwoRangeModel', Class.new(ActiveRecord::Base) do
      self.table_name = 'meetings'
      attr_accessor :period, :backup_period
      validates :period, :backup_period, overlap: true
    end)
    TwoRangeModel.new
    allow(TwoRangeModel).to receive(:columns_hash).and_return(
      'period' => double('column', name: 'period', type: :tstzrange),
      'backup_period' => double('column', name: 'backup_period', type: :tstzrange)
    )
    expect { TwoRangeModel.new.valid? }.to raise_error(OverlapValidator::UnsupportedColumnType, /validated on its own/)
  end

  # Relation#or keeps a NullRelation's emptiness on Rails 6.1/7.0 (fixed
  # upstream in 7.1) — the union must drop a nil range value's empty relation
  # instead of letting it hide the other validation's conflicts
  it 'a nil range value does not hide conflicts found by another overlap validation' do
    stub_const('DualValidationModel', Class.new(ActiveRecord::Base) do
      self.table_name = 'meetings'
      attr_accessor :period
      validates :period, overlap: true
      validates :starts_at, :ends_at, overlap: true
    end)
    DualValidationModel.new
    allow(DualValidationModel).to receive(:columns_hash).and_return(
      'period' => double('column', name: 'period', type: :tstzrange),
      'starts_at' => double('column', name: 'starts_at', type: :datetime),
      'ends_at' => double('column', name: 'ends_at', type: :datetime)
    )
    existing = Meeting.create!(starts_at: '2035-03-05'.to_date, ends_at: '2035-03-08'.to_date)
    record = DualValidationModel.new(starts_at: '2035-03-06'.to_date, ends_at: '2035-03-07'.to_date)
    expect(record.overlapping_records.pluck(:id)).to eq [existing.id]
  end
end
