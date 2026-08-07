require "#{File.dirname(__FILE__)}/../../../spec_helper"

# Issue #50: Rails registers ONE OverlapValidator instance per model class, so any
# state the validator keeps between building a query and running it is shared by
# every validation of that class. If another record of the same class is validated
# mid-build (concurrent thread, or reentrancy as simulated here), the first
# validation must still be checked against ITS OWN time range and scope — with the
# shared-state bug it silently runs with the other record's query instead
# (reported as ActiveRecord::PreparedStatementInvalid "missing value" in the
# narrower window, and as a wrong validation result in the wider one).
describe ReentrantMeeting do
  it 'validating another record mid-validation does not corrupt the running validation' do
    ReentrantMeeting.create!(user_id: 1, starts_at: '2011-01-05'.to_date, ends_at: '2011-01-08'.to_date)

    overlapping = ReentrantMeeting.new(user_id: 1, starts_at: '2011-01-06'.to_date, ends_at: '2011-01-07'.to_date)
    unrelated = ReentrantMeeting.new(user_id: 2, starts_at: '2012-06-01'.to_date, ends_at: '2012-06-02'.to_date)
    overlapping.during_scope_resolution = -> { expect(unrelated).to be_valid }

    expect(overlapping).not_to be_valid
    expect(overlapping.errors[:starts_at]).not_to be_empty
  end
end
