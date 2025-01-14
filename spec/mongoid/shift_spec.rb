require 'spec_helper'
require 'mongoid'

Mongoid.load!(File.expand_path('../../dummy/config/database.yml', __FILE__), :mongoid)

class MongoidShift
  include Mongoid::Document
  field :starts_at, type: Date
  field :ends_at, type: Date

  validates :starts_at, :ends_at, overlap: { load_overlapped: true }
end

describe MongoidShift do
  context 'Validation' do
    it 'create shift' do
      expect do
        MongoidShift.create(starts_at: '2022-01-01'.to_date, ends_at: '2022-01-02'.to_date)
      end.to change(MongoidShift, :count).by(1)
    end

    context 'simple validation' do
      let!(:existing_shift) { MongoidShift.create(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date) }

      OVERLAP_TIME_RANGES.each do |description, time_range|
        it "is not valid if exists shift which #{description}" do
          shift = MongoidShift.new(starts_at: time_range.first, ends_at: time_range.last)
          expect(shift).not_to be_valid
          expect(shift.errors[:starts_at]).not_to be_empty
          expect(shift.errors[:ends_at]).to be_empty
        end
      end

      it 'validate object which has not got overlap' do
        shift = MongoidShift.new(starts_at: '2022-01-09'.to_date, ends_at: '2022-01-11'.to_date)
        expect(shift).to be_valid
        expect(shift.errors[:starts_at]).to be_empty
        expect(shift.errors[:ends_at]).to be_empty

        shift = MongoidShift.new(starts_at: '2022-01-01'.to_date, ends_at: '2022-01-02'.to_date)
        expect(shift).to be_valid
        expect(shift.errors[:starts_at]).to be_empty
        expect(shift.errors[:ends_at]).to be_empty
      end

      describe '@overlapped_records' do
        it 'store the overlapped records' do
          shift = MongoidShift.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
          expect(shift).not_to be_valid
          expect(shift.instance_variable_get(:@overlapped_records)).to eq [existing_shift]
        end
      end
    end

    context 'Validation of endless objects' do
      it 'with overlap object' do
        MongoidShift.create(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        shift = MongoidShift.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        expect(shift).not_to be_valid
        shift = MongoidShift.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        expect(shift).not_to be_valid
        shift = MongoidShift.new(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)
        expect(shift).to be_valid
      end

      it 'with another endless object' do
        MongoidShift.create(starts_at: '2022-01-05'.to_date, ends_at: '2022-01-08'.to_date)

        shift = MongoidShift.new(starts_at: '2022-01-05'.to_date, ends_at: nil)
        expect(shift).not_to be_valid
        shift = MongoidShift.new(starts_at: nil, ends_at: '2022-01-05'.to_date)
        expect(shift).to be_valid
        shift = MongoidShift.new(starts_at: nil, ends_at: nil)
        expect(shift).not_to be_valid
      end
    end
  end
end
