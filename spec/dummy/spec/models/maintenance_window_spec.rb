require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe MaintenanceWindow do
  context 'Validation of timestamp ranges' do
    before do
      MaintenanceWindow.create!(starts_at: '2011-01-05 22:00'.to_datetime, ends_at: '2011-01-06 02:00'.to_datetime)
    end

    it 'is not valid if the windows overlap (across midnight)' do
      window = MaintenanceWindow.new(starts_at: '2011-01-06 01:00'.to_datetime, ends_at: '2011-01-06 03:00'.to_datetime)
      expect(window).not_to be_valid
      expect(window.errors[:starts_at]).not_to be_empty
    end

    it 'is valid if the windows do not overlap' do
      window = MaintenanceWindow.new(starts_at: '2011-01-06 03:00'.to_datetime, ends_at: '2011-01-06 05:00'.to_datetime)
      expect(window).to be_valid
      expect(window.errors[:starts_at]).to be_empty
    end
  end
end
