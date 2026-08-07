require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe Meeting do
  context 'Validation' do
    it 'create meeting' do
      expect do
        FactoryBot.create(:shift)
      end.to change(Shift, :count).by(1)
    end

    context 'validation with shift configuration' do
      before do
        FactoryBot.create(:shift)
      end

      it 'is not valid if exists shift within wider range' do
        shift = FactoryBot.build(:shift, starts_at: '2011-01-09'.to_date, ends_at: '2011-01-11'.to_date)
        expect(shift).not_to be_valid
        expect(shift.errors[:starts_at]).not_to be_empty
        expect(shift.errors[:ends_at]).to be_empty

        shift = FactoryBot.build(:shift, starts_at: '2011-01-01'.to_date, ends_at: '2011-01-04'.to_date)
        expect(shift).not_to be_valid
        expect(shift.errors[:starts_at]).not_to be_empty
        expect(shift.errors[:ends_at]).to be_empty
      end

      it ' validate object which has not got overlap' do
        shift = FactoryBot.build(:shift, starts_at: '2011-01-10'.to_date, ends_at: '2011-01-11'.to_date)
        expect(shift).to be_valid
        expect(shift.errors[:starts_at]).to be_empty
        expect(shift.errors[:ends_at]).to be_empty

        shift = FactoryBot.build(:shift, starts_at: '2011-01-01'.to_date, ends_at: '2011-01-02'.to_date)
        expect(shift).to be_valid
        expect(shift.errors[:starts_at]).to be_empty
        expect(shift.errors[:ends_at]).to be_empty
      end
    end
  end
end
