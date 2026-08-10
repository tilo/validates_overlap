require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe Appointment do
  context 'Validation of datetime ranges (time-of-day precision)' do
    before do
      Appointment.create!(starts_at: '2011-01-05 10:00'.to_datetime, ends_at: '2011-01-05 12:00'.to_datetime)
    end

    it 'is not valid if the appointments overlap within the same day' do
      appointment = Appointment.new(starts_at: '2011-01-05 11:00'.to_datetime, ends_at: '2011-01-05 13:00'.to_datetime)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:starts_at]).not_to be_empty
    end

    it 'is not valid if the appointments touch at a boundary (edges count as overlap by default)' do
      appointment = Appointment.new(starts_at: '2011-01-05 12:00'.to_datetime, ends_at: '2011-01-05 14:00'.to_datetime)
      expect(appointment).not_to be_valid
    end

    it 'is valid if the appointments are on the same day but do not overlap' do
      appointment = Appointment.new(starts_at: '2011-01-05 12:30'.to_datetime, ends_at: '2011-01-05 14:00'.to_datetime)
      expect(appointment).to be_valid
      expect(appointment.errors[:starts_at]).to be_empty
    end
  end
end
