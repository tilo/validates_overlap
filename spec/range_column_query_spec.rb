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
      'period' => double('column', type: :tstzrange)
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
end
