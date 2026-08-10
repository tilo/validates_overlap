require "#{File.dirname(__FILE__)}/../../../spec_helper"

# Time-of-day is a cyclic domain: every pair of values denotes some valid range,
# so wraparound intent is indistinguishable from swapped fields — the validator
# refuses to operate on :time columns instead of answering wrong (see README)
describe DailyWindow do
  it 'raises UnsupportedColumnType when a range attribute is a :time column' do
    window = DailyWindow.new(starts_at: '09:00', ends_at: '12:00')
    expect { window.valid? }.to raise_error(OverlapValidator::UnsupportedColumnType, /:time column/)
  end
end
