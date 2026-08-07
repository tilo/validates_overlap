FactoryBot.define do
  factory :time_slot do
    starts_at { '2011-01-05'.to_date }
    ends_at { '2011-01-08'.to_date }
  end
end
