require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe Position do
  it 'create position' do
    expect do
      FactoryBot.create(:position)
    end.to change(Position, :count).by(1)
  end

  context 'Validation with scope and association' do
    it 'is not valid if exists time slot which have position with same person' do
      time_slot1 = FactoryBot.create(:time_slot, starts_at: '2012-10-11'.to_date, ends_at: '2012-10-13'.to_date)
      time_slot2 = FactoryBot.create(:time_slot, starts_at: '2012-10-12'.to_date, ends_at: '2012-10-13'.to_date)
      user = FactoryBot.create(:user)
      position1 = FactoryBot.create(:position, time_slot: time_slot1, user: user)
      position2 = FactoryBot.build(:position, time_slot: time_slot2, user: user)
      expect(position2).not_to be_valid
      expect(position2.errors[:base]).not_to be_empty
    end

    it 'is be valid if exists time slot which have position with same person' do
      time_slot1 = FactoryBot.create(:time_slot, starts_at: '2012-10-11'.to_date, ends_at: '2012-10-13'.to_date)
      time_slot2 = FactoryBot.create(:time_slot, starts_at: '2012-10-14'.to_date, ends_at: '2012-10-15'.to_date)
      user = FactoryBot.create(:user)
      position1 = FactoryBot.create(:position, time_slot: time_slot1, user: user)
      position2 = FactoryBot.build(:position, time_slot: time_slot2, user: user)
      expect(position2).to be_valid
      expect(position2.errors[:base]).to be_empty
    end
  end
end
