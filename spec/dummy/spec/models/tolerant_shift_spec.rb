require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe TolerantShift do
  context 'validation with overlap tolerance (range-shrinking shifts)' do
    before do
      FactoryBot.create(:tolerant_shift)
    end

    it 'is valid if the overlap stays within the tolerated 2 days' do
      shift = FactoryBot.build(:tolerant_shift, starts_at: '2011-01-07'.to_date, ends_at: '2011-01-10'.to_date)
      expect(shift).to be_valid
      expect(shift.errors[:starts_at]).to be_empty
    end

    it 'is not valid if the overlap exceeds the tolerated 2 days' do
      shift = FactoryBot.build(:tolerant_shift, starts_at: '2011-01-06'.to_date, ends_at: '2011-01-10'.to_date)
      expect(shift).not_to be_valid
      expect(shift.errors[:starts_at]).not_to be_empty
    end
  end
end
