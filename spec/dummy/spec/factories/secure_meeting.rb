FactoryBot.define do
  factory :secure_meeting do
    id { SecureRandom.uuid }
    starts_at { '2010-11-05'.to_date }
    ends_at { '2010-11-08'.to_date }
  end
end
