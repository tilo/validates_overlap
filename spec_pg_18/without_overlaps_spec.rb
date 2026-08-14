raise 'PostgreSQL-only specs: run with DB=postgres bundle exec rspec spec_pg_18 against a PostgreSQL 18+ server' unless ENV['DB'] == 'postgres'
ENV['PG_SPECS'] = '18'

require "#{File.dirname(__FILE__)}/../spec/spec_helper"

if ActiveRecord::Base.connection.database_version < 180_000
  raise "spec_pg_18 needs a PostgreSQL 18+ server, this one reports #{ActiveRecord::Base.connection.database_version} — locally e.g.: PGPORT=5433 DB=postgres bundle exec rspec spec_pg_18"
end

# add_overlap_constraint(..., without_overlaps: true) — PostgreSQL 18's temporal
# unique constraint (UNIQUE (scope, range WITHOUT OVERLAPS)). PostgreSQL enforces
# it as an exclusion constraint, so a violation raises PG::ExclusionViolation and
# RescueExclusionViolation works unchanged. Empty ranges are rejected by the
# database — the one place this form is stricter than the validator.
describe 'add_overlap_constraint with without_overlaps: true' do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.drop_table :pg_wo_slots, if_exists: true
    connection.create_table :pg_wo_slots do |t|
      t.tstzrange :period
      t.integer :user_id, null: false
    end
    @migration = Class.new(ActiveRecord::Migration[6.1]) do
      def up
        add_overlap_constraint :pg_wo_slots, :period, scope: :user_id, without_overlaps: true
      end

      def down
        remove_overlap_constraint :pg_wo_slots
      end
    end
    ActiveRecord::Migration.suppress_messages { @migration.migrate(:up) }
    insert(1, '[2030-01-01 10:00,2030-01-01 12:00)')
  end

  after do
    connection.drop_table :pg_wo_slots, if_exists: true
  end

  # each statement runs in its own savepoint: an expected constraint violation
  # would otherwise poison the example's wrapping transaction
  def exec_sql(sql)
    connection.transaction(requires_new: true) { connection.execute(sql) }
  end

  def insert(user_id, range_literal)
    exec_sql("INSERT INTO pg_wo_slots (user_id, period) VALUES (#{user_id}, '#{range_literal}')")
  end

  it 'rejects an overlapping range for the same scope with an exclusion violation' do
    expect { insert(1, '[2030-01-01 11:00,2030-01-01 13:00)') }.to raise_error(ActiveRecord::StatementInvalid) { |e|
      expect(e.cause).to be_a(PG::ExclusionViolation)
    }
  end

  it 'accepts an overlapping range for another scope' do
    expect { insert(2, '[2030-01-01 11:00,2030-01-01 13:00)') }.not_to raise_error
  end

  it 'accepts a touching half-open range (bounds live in the value)' do
    expect { insert(1, '[2030-01-01 12:00,2030-01-01 14:00)') }.not_to raise_error
  end

  it 'accepts NULL ranges, like the EXCLUDE form' do
    expect { exec_sql('INSERT INTO pg_wo_slots (user_id, period) VALUES (1, NULL)') }.not_to raise_error
  end

  # stricter than the EXCLUDE form and than the validator (where an empty range
  # conflicts with nothing): temporal constraints reject empty ranges outright
  it 'rejects an empty range value' do
    expect { insert(1, 'empty') }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it 'remove_overlap_constraint drops it so overlapping rows insert again' do
    ActiveRecord::Migration.suppress_messages { @migration.migrate(:down) }
    expect { insert(1, '[2030-01-01 11:00,2030-01-01 13:00)') }.not_to raise_error
  end

  it 'RescueExclusionViolation turns the violation into a validation error' do
    stub_const('WoSlot', Class.new(ActiveRecord::Base) do
      self.table_name = 'pg_wo_slots'
      validates :period, overlap: { scope: 'user_id' }
      include ValidatesOverlap::RescueExclusionViolation
    end)
    slot = WoSlot.new(user_id: 1, period: Time.utc(2030, 1, 1, 11)...Time.utc(2030, 1, 1, 13))
    result = WoSlot.transaction(requires_new: true) { slot.save(validate: false) }
    expect(result).to be false
    expect(slot.errors[:period]).to eq ['overlaps with another record']
  end
end
