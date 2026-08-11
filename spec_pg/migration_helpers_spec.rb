raise 'PostgreSQL-only specs: run with DB=postgres bundle exec rspec spec_pg' unless ENV['DB'] == 'postgres'
ENV['PG_SPECS'] = '1'

require "#{File.dirname(__FILE__)}/../spec/spec_helper"

# add_overlap_constraint / remove_overlap_constraint generate a PostgreSQL
# exclusion constraint that closes the check-then-act race the validation
# alone cannot (see the README concurrency section)
describe ValidatesOverlap::MigrationHelpers do
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(&block)
    migration = Class.new(ActiveRecord::Migration[6.1], &block)
    ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
  end

  before do
    connection.drop_table :pg_bookings, if_exists: true
    connection.create_table :pg_bookings do |t|
      t.integer :user_id
      t.datetime :starts_at
      t.datetime :ends_at
    end
  end

  after do
    connection.drop_table :pg_bookings, if_exists: true
  end

  # each statement runs in its own savepoint: an expected constraint violation
  # would otherwise poison the example's wrapping transaction
  # (PG::InFailedSqlTransaction on every statement after it)
  def exec_sql(sql)
    connection.transaction(requires_new: true) { connection.execute(sql) }
  end

  def insert(user_id, starts_at, ends_at)
    exec_sql("INSERT INTO pg_bookings (user_id, starts_at, ends_at) VALUES (#{user_id}, '#{starts_at}', '#{ends_at}')")
  end

  context 'with a scope column' do
    before do
      migrate do
        def change
          add_overlap_constraint :pg_bookings, :starts_at, :ends_at, scope: :user_id
        end
      end
      insert(1, '2030-01-01 10:00', '2030-01-01 12:00')
    end

    it 'rejects an overlapping row for the same scope at the database level' do
      expect { insert(1, '2030-01-01 11:00', '2030-01-01 13:00') }.to raise_error(ActiveRecord::StatementInvalid) { |e|
        expect(e.cause).to be_a(PG::ExclusionViolation)
      }
    end

    it 'rejects a touching row for the same scope (edges conflict, matching the validator default)' do
      expect { insert(1, '2030-01-01 12:00', '2030-01-01 14:00') }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'accepts an overlapping row for another scope' do
      expect { insert(2, '2030-01-01 11:00', '2030-01-01 13:00') }.not_to raise_error
    end

    it 'accepts a non-overlapping row for the same scope' do
      expect { insert(1, '2030-01-01 12:30', '2030-01-01 14:00') }.not_to raise_error
    end

    it 'treats a NULL endpoint as open-ended, matching the validator' do
      expect { exec_sql("INSERT INTO pg_bookings (user_id, starts_at, ends_at) VALUES (1, '2030-01-01 13:00', NULL)") }.not_to raise_error
      expect { insert(1, '2030-06-01 10:00', '2030-06-01 11:00') }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  context 'with exclude_edges: true' do
    before do
      migrate do
        def change
          add_overlap_constraint :pg_bookings, :starts_at, :ends_at, scope: :user_id, exclude_edges: true
        end
      end
      insert(1, '2030-01-01 10:00', '2030-01-01 12:00')
    end

    it 'accepts a touching row (half-open ranges)' do
      expect { insert(1, '2030-01-01 12:00', '2030-01-01 14:00') }.not_to raise_error
    end

    it 'still rejects a genuinely overlapping row' do
      expect { insert(1, '2030-01-01 11:59', '2030-01-01 14:00') }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  context 'without a scope' do
    before do
      migrate do
        def change
          add_overlap_constraint :pg_bookings, :starts_at, :ends_at
        end
      end
      insert(1, '2030-01-01 10:00', '2030-01-01 12:00')
    end

    it 'rejects overlapping rows regardless of any other column' do
      expect { insert(99, '2030-01-01 11:00', '2030-01-01 13:00') }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  context 'range type inference' do
    before do
      connection.drop_table :pg_blocks, if_exists: true
      connection.create_table :pg_blocks do |t|
        t.integer :range_start
        t.integer :range_end
      end
      migrate do
        def change
          add_overlap_constraint :pg_blocks, :range_start, :range_end
        end
      end
    end

    after do
      connection.drop_table :pg_blocks, if_exists: true
    end

    it 'infers int4range for integer columns' do
      exec_sql('INSERT INTO pg_blocks (range_start, range_end) VALUES (100, 199)')
      expect { exec_sql('INSERT INTO pg_blocks (range_start, range_end) VALUES (150, 250)') }.to raise_error(ActiveRecord::StatementInvalid)
      expect { exec_sql('INSERT INTO pg_blocks (range_start, range_end) VALUES (200, 299)') }.not_to raise_error
    end

    it 'infers daterange for date columns' do
      connection.create_table(:pg_seasons) { |t| t.date :from_on; t.date :until_on }
      migrate do
        def change
          add_overlap_constraint :pg_seasons, :from_on, :until_on
        end
      end
      exec_sql("INSERT INTO pg_seasons (from_on, until_on) VALUES ('2030-01-01', '2030-03-31')")
      expect { exec_sql("INSERT INTO pg_seasons (from_on, until_on) VALUES ('2030-03-01', '2030-05-31')") }.to raise_error(ActiveRecord::StatementInvalid)
    ensure
      connection.drop_table :pg_seasons, if_exists: true
    end

    it 'infers numrange for decimal columns' do
      connection.create_table(:pg_bands) { |t| t.decimal :low, precision: 10, scale: 2; t.decimal :high, precision: 10, scale: 2 }
      migrate do
        def change
          add_overlap_constraint :pg_bands, :low, :high
        end
      end
      exec_sql('INSERT INTO pg_bands (low, high) VALUES (0.00, 9.99)')
      expect { exec_sql('INSERT INTO pg_bands (low, high) VALUES (5.00, 19.99)') }.to raise_error(ActiveRecord::StatementInvalid)
    ensure
      connection.drop_table :pg_bands, if_exists: true
    end

    it 'raises ArgumentError for column types with no PostgreSQL range type' do
      connection.create_table(:pg_names) { |t| t.string :range_start; t.string :range_end }
      expect {
        migrate do
          def change
            add_overlap_constraint :pg_names, :range_start, :range_end
          end
        end
      }.to raise_error(ArgumentError, /cannot infer a range type/)
    ensure
      connection.drop_table :pg_names, if_exists: true
    end
  end

  context 'removal' do
    before do
      migrate do
        def change
          add_overlap_constraint :pg_bookings, :starts_at, :ends_at, scope: :user_id
        end
      end
      migrate do
        def change
          remove_overlap_constraint :pg_bookings
        end
      end
      insert(1, '2030-01-01 10:00', '2030-01-01 12:00')
    end

    it 'drops the constraint so overlapping rows insert again' do
      expect { insert(1, '2030-01-01 11:00', '2030-01-01 13:00') }.not_to raise_error
    end
  end
end
