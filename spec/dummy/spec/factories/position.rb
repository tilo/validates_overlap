FactoryBot.define do
  factory :position do
    association(:user, factory: :user)
    association(:time_slot, factory: :time_slot)
  end
end
