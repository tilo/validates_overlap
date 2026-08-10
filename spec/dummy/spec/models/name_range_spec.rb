require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe NameRange do
  context 'Validation of string ranges' do
    before do
      NameRange.create!(range_start: 'Adams', range_end: 'Fisher')
    end

    it 'is not valid if the name ranges overlap' do
      range = NameRange.new(range_start: 'Baker', range_end: 'Miller')
      expect(range).not_to be_valid
      expect(range.errors[:range_start]).not_to be_empty
    end

    it 'is not valid if the ranges touch at a boundary (edges count as overlap by default)' do
      range = NameRange.new(range_start: 'Fisher', range_end: 'Miller')
      expect(range).not_to be_valid
    end

    it 'is valid if the name ranges are disjoint' do
      range = NameRange.new(range_start: 'Garcia', range_end: 'Miller')
      expect(range).to be_valid
      expect(range.errors[:range_start]).to be_empty
    end

    context 'with open-ended (nil) endpoints' do
      it 'is not valid if an upward-open range overlaps' do
        range = NameRange.new(range_start: 'Baker', range_end: nil)
        expect(range).not_to be_valid
      end

      it 'is not valid if a downward-open range overlaps' do
        range = NameRange.new(range_start: nil, range_end: 'Baker')
        expect(range).not_to be_valid
      end

      it 'is valid if an upward-open range starts beyond the existing range' do
        range = NameRange.new(range_start: 'Garcia', range_end: nil)
        expect(range).to be_valid
      end
    end
  end
end
