FactoryBot.define do
  factory :shift do
    starts_at { '2011-01-05'.to_date }
    ends_at { '2011-01-08'.to_date }
  end

  factory :tolerant_shift, class: TolerantShift do
    starts_at { '2011-01-05'.to_date }
    ends_at { '2011-01-08'.to_date }
  end
end
