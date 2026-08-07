FactoryBot.define do
  factory :johns_meeting, class: UserMeeting do |u|
    starts_at { '2011-01-05'.to_date }
    ends_at { '2011-01-08'.to_date }
    user_id { 1 }
  end

  factory :peters_meeting, class: UserMeeting do |u|
    starts_at { '2011-01-05'.to_date }
    ends_at { '2011-01-08'.to_date }
    user_id { 2 }
  end
end
