require "#{File.dirname(__FILE__)}/../../../spec_helper"

# Part of the range-type coverage — see the note in number_range_spec.rb
describe PriceBand do
  context 'Validation of decimal ranges' do
    before do
      PriceBand.create!(range_start: BigDecimal('0.00'), range_end: BigDecimal('9.99'))
    end

    it 'is not valid if the price bands overlap' do
      band = PriceBand.new(range_start: BigDecimal('5.50'), range_end: BigDecimal('19.99'))
      expect(band).not_to be_valid
      expect(band.errors[:range_start]).not_to be_empty
    end

    it 'is not valid if the bands touch at a boundary (edges count as overlap by default)' do
      band = PriceBand.new(range_start: BigDecimal('9.99'), range_end: BigDecimal('19.99'))
      expect(band).not_to be_valid
    end

    it 'is valid if the price bands are disjoint' do
      band = PriceBand.new(range_start: BigDecimal('10.00'), range_end: BigDecimal('19.99'))
      expect(band).to be_valid
      expect(band.errors[:range_start]).to be_empty
    end

    context 'with open-ended (nil) endpoints' do
      it 'is not valid if an upward-open band overlaps' do
        band = PriceBand.new(range_start: BigDecimal('5.00'), range_end: nil)
        expect(band).not_to be_valid
      end

      it 'is valid if an upward-open band starts above the existing band' do
        band = PriceBand.new(range_start: BigDecimal('10.00'), range_end: nil)
        expect(band).to be_valid
      end
    end
  end
end
