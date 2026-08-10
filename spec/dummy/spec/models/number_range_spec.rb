require "#{File.dirname(__FILE__)}/../../../spec_helper"

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
  end
end
