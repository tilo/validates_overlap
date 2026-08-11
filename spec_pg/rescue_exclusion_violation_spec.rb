raise 'PostgreSQL-only specs: run with DB=postgres bundle exec rspec spec_pg' unless ENV['DB'] == 'postgres'
ENV['PG_SPECS'] = '1'

require "#{File.dirname(__FILE__)}/../spec/spec_helper"

# The race window: validation sees no conflict, but by insert time a conflicting
# row exists. save(validate: false) simulates exactly that — the constraint
# fires, and the concern turns it into a normal validation failure.
describe ValidatesOverlap::RescueExclusionViolation do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.drop_table :pg_bookings, if_exists: true
    connection.create_table :pg_bookings do |t|
      t.integer :user_id
      t.datetime :starts_at
      t.datetime :ends_at
    end
    migration = Class.new(ActiveRecord::Migration[6.1]) do
      def change
        add_overlap_constraint :pg_bookings, :starts_at, :ends_at, scope: :user_id
      end
    end
    ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }

    stub_const('PgBooking', Class.new(ActiveRecord::Base) do
      self.table_name = 'pg_bookings'
      validates :starts_at, :ends_at, overlap: { scope: 'user_id' }
      include ValidatesOverlap::RescueExclusionViolation
    end)

    PgBooking.transaction(requires_new: true) do
      PgBooking.create!(user_id: 1, starts_at: '2030-01-01 10:00', ends_at: '2030-01-01 12:00')
    end
  end

  after do
    connection.drop_table :pg_bookings, if_exists: true
  end

  def overlapping_booking
    PgBooking.new(user_id: 1, starts_at: '2030-01-01 11:00'.to_datetime, ends_at: '2030-01-01 13:00'.to_datetime)
  end

  it 'turns the constraint violation into a validation error instead of raising' do
    booking = overlapping_booking
    result = PgBooking.transaction(requires_new: true) { booking.save(validate: false) }
    expect(result).to be false
    expect(booking.errors[:starts_at]).to eq ['overlaps with another record']
    expect(booking).not_to be_persisted
  end

  it 'makes save! raise RecordInvalid (errors populated) instead of StatementInvalid' do
    booking = overlapping_booking
    expect {
      PgBooking.transaction(requires_new: true) { booking.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(booking.errors[:starts_at]).to eq ['overlaps with another record']
  end

  it 'does not interfere with a normal successful save' do
    booking = PgBooking.new(user_id: 2, starts_at: '2031-01-01 10:00'.to_datetime, ends_at: '2031-01-01 12:00'.to_datetime)
    expect(PgBooking.transaction(requires_new: true) { booking.save }).to be true
    expect(booking).to be_persisted
  end

  it 'still catches the normal (non-race) case through the validator first' do
    booking = overlapping_booking
    expect(booking.save).to be false
    expect(booking.errors[:starts_at]).to eq ['overlaps with another record']
  end

  it 'adds the error to :base when the model has no overlap validator' do
    stub_const('BareBooking', Class.new(ActiveRecord::Base) do
      self.table_name = 'pg_bookings'
      include ValidatesOverlap::RescueExclusionViolation
    end)
    booking = BareBooking.new(user_id: 1, starts_at: '2030-01-01 11:00'.to_datetime, ends_at: '2030-01-01 13:00'.to_datetime)
    expect(BareBooking.transaction(requires_new: true) { booking.save }).to be false
    expect(booking.errors[:base]).not_to be_empty
  end
end
