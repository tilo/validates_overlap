require "#{File.dirname(__FILE__)}/../../../spec_helper"

# Part of the range-type coverage — see the note in number_range_spec.rb
describe DailyWindow do
  context 'Validation of pure time-of-day ranges' do
    before do
      DailyWindow.create!(starts_at: '09:00', ends_at: '12:00')
    end

    it 'is not valid if the time windows overlap' do
      window = DailyWindow.new(starts_at: '11:00', ends_at: '14:00')
      expect(window).not_to be_valid
      expect(window.errors[:starts_at]).not_to be_empty
    end

    it 'is not valid if the windows touch at a boundary (edges count as overlap by default)' do
      window = DailyWindow.new(starts_at: '12:00', ends_at: '14:00')
      expect(window).not_to be_valid
    end

    it 'is valid if the time windows do not overlap' do
      window = DailyWindow.new(starts_at: '12:30', ends_at: '14:00')
      expect(window).to be_valid
      expect(window.errors[:starts_at]).to be_empty
    end
  end
end
