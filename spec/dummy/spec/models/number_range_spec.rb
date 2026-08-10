require "#{File.dirname(__FILE__)}/../../../spec_helper"

# Part of the range-type coverage: the same overlap contract is asserted once per
# column type (date, datetime, timestamp, integer, decimal, string). The SQL
# generation is type-blind, so options like exclude_edges/scope are not repeated
# per type; the type-sensitive paths — shift arithmetic and open-ended (nil)
# endpoints — are covered where behavior differs by type.
describe NumberRange do
  context 'Validation of integer ranges' do
    before do
      NumberRange.create!(range_start: 100, range_end: 199)
    end

    it 'is not valid if the number ranges overlap' do
      range = NumberRange.new(range_start: 150, range_end: 250)
      expect(range).not_to be_valid
      expect(range.errors[:range_start]).not_to be_empty
    end

    it 'is not valid if the ranges touch at a boundary (edges count as overlap by default)' do
      range = NumberRange.new(range_start: 199, range_end: 299)
      expect(range).not_to be_valid
    end

    it 'is valid if the number ranges are disjoint' do
      range = NumberRange.new(range_start: 200, range_end: 299)
      expect(range).to be_valid
      expect(range.errors[:range_start]).to be_empty
    end

    context 'with open-ended (nil) endpoints' do
      it 'is not valid if an upward-open range overlaps' do
        range = NumberRange.new(range_start: 150, range_end: nil)
        expect(range).not_to be_valid
      end

      it 'is not valid if a downward-open range overlaps' do
        range = NumberRange.new(range_start: nil, range_end: 150)
        expect(range).not_to be_valid
      end

      it 'is valid if an upward-open range starts above the existing range' do
        range = NumberRange.new(range_start: 200, range_end: nil)
        expect(range).to be_valid
      end

      it 'is valid if a downward-open range ends below the existing range' do
        range = NumberRange.new(range_start: nil, range_end: 99)
        expect(range).to be_valid
      end
    end
  end
end

describe GappedNumberRange do
  context 'integer shifts widening the range (gap of 10 enforced)' do
    before do
      GappedNumberRange.create!(range_start: 100, range_end: 199)
    end

    it 'is not valid if the gap to the existing range is smaller than 10' do
      range = GappedNumberRange.new(range_start: 205, range_end: 300)
      expect(range).not_to be_valid
    end

    it 'is valid if the gap to the existing range is at least 10' do
      range = GappedNumberRange.new(range_start: 210, range_end: 300)
      expect(range).to be_valid
    end
  end
end

describe TolerantNumberRange do
  context 'integer shifts shrinking the range (10 numbers of overlap tolerated)' do
    before do
      TolerantNumberRange.create!(range_start: 100, range_end: 199)
    end

    it 'is valid if the overlap stays within the tolerated 10 numbers' do
      range = TolerantNumberRange.new(range_start: 190, range_end: 290)
      expect(range).to be_valid
    end

    it 'is not valid if the overlap exceeds the tolerated 10 numbers' do
      range = TolerantNumberRange.new(range_start: 180, range_end: 290)
      expect(range).not_to be_valid
    end
  end
end
