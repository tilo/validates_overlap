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
  end
end
