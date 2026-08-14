require "#{File.dirname(__FILE__)}/spec_helper"

# Adapter-independent contracts: the generated SQL, the range-type inference,
# and the adapter guard. The behavior against a real PostgreSQL database
# (constraints actually rejecting rows) is covered by spec_pg/.
describe ValidatesOverlap::MigrationHelpers do
  let(:helper_class) do
    Class.new do
      include ValidatesOverlap::MigrationHelpers
      attr_accessor :connection
      attr_reader :executed, :extensions, :constraints_added, :constraints_removed, :said

      def enable_extension(name)
        (@extensions ||= []) << name
      end

      def execute(sql)
        (@executed ||= []) << sql
      end

      # in a real migration these dispatch to the connection / command recorder;
      # the helper only calls them when the connection offers them (Rails 7.1+)
      def add_exclusion_constraint(table, expression, **options)
        (@constraints_added ||= []) << [table, expression, options]
      end

      def remove_exclusion_constraint(table, **options)
        (@constraints_removed ||= []) << [table, options]
      end

      def say(message)
        (@said ||= []) << message
      end
    end
  end

  let(:helper) { helper_class.new }

  def fake_column(name, type, sql_type, limit: nil, null: false)
    double("column-#{name}", name: name.to_s, type: type, sql_type: sql_type, limit: limit, null: null)
  end

  def connect(columns)
    connection = double('connection', adapter_name: 'PostgreSQL')
    allow(connection).to receive(:quote_table_name) { |name| %("#{name}") }
    allow(connection).to receive(:quote_column_name) { |name| %("#{name}") }
    allow(connection).to receive(:columns) { columns }
    allow(connection).to receive(:extension_enabled?).and_return(false)
    helper.connection = connection
  end

  let(:datetime_columns) do
    [fake_column(:starts_at, :datetime, 'timestamp(6) without time zone'),
     fake_column(:ends_at, :datetime, 'timestamp(6) without time zone')]
  end

  context 'generated SQL' do
    before { connect(datetime_columns) }

    it 'builds an exclusion constraint with scope columns, inclusive edges, and a default name' do
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, scope: :user_id)
      sql = helper.executed.first
      expect(sql).to include('ALTER TABLE "meetings"')
      expect(sql).to include('ADD CONSTRAINT "meetings_no_overlap"')
      expect(sql).to include('EXCLUDE USING gist ("user_id" WITH =, tsrange("starts_at", "ends_at", \'[]\') WITH &&)')
      expect(helper.extensions).to eq ['btree_gist']
    end

    it 'omits scope clauses and btree_gist when no scope is given' do
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at)
      expect(helper.executed.first).to include('EXCLUDE USING gist (tsrange("starts_at", "ends_at", \'[]\') WITH &&)')
      expect(helper.extensions).to be_nil
    end

    it 'uses half-open ranges with exclude_edges: true' do
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, exclude_edges: true)
      expect(helper.executed.first).to include(%q{tsrange("starts_at", "ends_at", '[)') WITH &&})
    end

    it 'accepts a custom constraint name and an explicit range type' do
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, name: 'my_constraint', range_type: 'tstzrange')
      expect(helper.executed.first).to include('ADD CONSTRAINT "my_constraint"')
      expect(helper.executed.first).to include('tstzrange(')
    end

    it 'drops the constraint by its default name' do
      helper.remove_overlap_constraint(:meetings)
      expect(helper.executed.first).to eq 'ALTER TABLE "meetings" DROP CONSTRAINT "meetings_no_overlap"'
    end

    it 'drops the constraint by a custom name' do
      helper.remove_overlap_constraint(:meetings, name: 'my_constraint')
      expect(helper.executed.first).to eq 'ALTER TABLE "meetings" DROP CONSTRAINT "my_constraint"'
    end

    it 'does not enable btree_gist when it is already enabled' do
      allow(helper.connection).to receive(:extension_enabled?).and_return(true)
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, scope: :user_id)
      expect(helper.extensions).to be_nil
    end
  end

  # NULL = NULL is not true in SQL: the constraint never restricts rows whose scope
  # value is NULL, while the validator DOES match NULL scope values against each other
  # (documented in docs/postgresql.md; database behavior characterized in spec_pg/)
  context 'nullable scope columns' do
    it 'warns when a scope column allows NULL' do
      connect(datetime_columns + [fake_column(:user_id, :integer, 'integer', limit: 4, null: true)])
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, scope: :user_id)
      expect(helper.said.join).to match(/scope column user_id on meetings allows NULL/)
    end

    it 'does not warn when the scope column is NOT NULL' do
      connect(datetime_columns + [fake_column(:user_id, :integer, 'integer', limit: 4, null: false)])
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, scope: :user_id)
      expect(helper.said).to be_nil
    end

    it 'does not warn without a scope' do
      connect(datetime_columns)
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at)
      expect(helper.said).to be_nil
    end
  end

  # On Rails 7.1+ the connection offers add_exclusion_constraint / remove_exclusion_constraint;
  # delegating to them (instead of raw execute) makes the helpers invertible, so they
  # work in def change migrations. The behavior is verified against a real database
  # in spec_pg/ ('reversibility in def change'); these specs pin the delegation contract.
  context 'delegation on Rails 7.1+' do
    before do
      connect(datetime_columns)
      # stubbing the messages makes the connection double answer respond_to? with true —
      # the capability gate the helper checks; the calls themselves land on the migration
      allow(helper.connection).to receive(:add_exclusion_constraint)
      allow(helper.connection).to receive(:remove_exclusion_constraint)
    end

    it 'adds the constraint via add_exclusion_constraint instead of raw SQL' do
      helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, scope: :user_id)
      expect(helper.executed).to be_nil
      expect(helper.constraints_added).to eq [[:meetings, %q{"user_id" WITH =, tsrange("starts_at", "ends_at", '[]') WITH &&}, { using: :gist, name: 'meetings_no_overlap' }]]
    end

    it 'removes the constraint with a plain DROP CONSTRAINT — remove_exclusion_constraint would refuse a temporal unique constraint' do
      helper.remove_overlap_constraint(:meetings, name: 'my_constraint')
      expect(helper.constraints_removed).to be_nil
      expect(helper.executed.first).to eq 'ALTER TABLE "meetings" DROP CONSTRAINT "my_constraint"'
    end
  end

  context 'range type inference' do
    def inferred_type_for(*columns)
      connect(columns)
      helper.add_overlap_constraint(:things, columns[0].name, columns[1].name)
      helper.executed.first[/(\w+range)\(/, 1]
    end

    it 'maps datetime columns to tsrange' do
      expect(inferred_type_for(*datetime_columns)).to eq 'tsrange'
    end

    it 'maps timezone-aware datetime columns to tstzrange' do
      columns = [fake_column(:starts_at, :datetime, 'timestamp(6) with time zone'),
                 fake_column(:ends_at, :datetime, 'timestamp(6) with time zone')]
      expect(inferred_type_for(*columns)).to eq 'tstzrange'
    end

    it 'maps date columns to daterange' do
      columns = [fake_column(:from_on, :date, 'date'), fake_column(:until_on, :date, 'date')]
      expect(inferred_type_for(*columns)).to eq 'daterange'
    end

    it 'maps integer columns to int4range' do
      columns = [fake_column(:range_start, :integer, 'integer', limit: 4), fake_column(:range_end, :integer, 'integer', limit: 4)]
      expect(inferred_type_for(*columns)).to eq 'int4range'
    end

    it 'maps bigint columns to int8range' do
      columns = [fake_column(:range_start, :integer, 'bigint', limit: 8), fake_column(:range_end, :integer, 'bigint', limit: 8)]
      expect(inferred_type_for(*columns)).to eq 'int8range'
    end

    it 'maps decimal columns to numrange' do
      columns = [fake_column(:low, :decimal, 'numeric(10,2)'), fake_column(:high, :decimal, 'numeric(10,2)')]
      expect(inferred_type_for(*columns)).to eq 'numrange'
    end

    it 'raises for column types without a PostgreSQL range type' do
      connect([fake_column(:range_start, :string, 'character varying'), fake_column(:range_end, :string, 'character varying')])
      expect { helper.add_overlap_constraint(:things, :range_start, :range_end) }.to raise_error(ArgumentError, /cannot infer a range type/)
    end

    it 'raises when the two columns have different types' do
      connect([fake_column(:starts_at, :datetime, 'timestamp(6) without time zone'), fake_column(:range_end, :integer, 'integer', limit: 4)])
      expect { helper.add_overlap_constraint(:things, :starts_at, :range_end) }.to raise_error(ArgumentError, /different types/)
    end

    it 'raises when a named column does not exist' do
      connect(datetime_columns)
      expect { helper.add_overlap_constraint(:things, :nope, :ends_at) }.to raise_error(ArgumentError, /no column nope/)
    end
  end

  context 'single range column form' do
    let(:range_columns) do
      [fake_column(:period, :tstzrange, 'tstzrange'), fake_column(:user_id, :integer, 'integer', limit: 4)]
    end

    it 'uses the range column directly with the && operator' do
      connect(range_columns)
      helper.add_overlap_constraint(:meetings, :period, scope: :user_id)
      expect(helper.executed.first).to include('EXCLUDE USING gist ("user_id" WITH =, "period" WITH &&)')
    end

    it 'rejects exclude_edges — bound inclusivity is part of the range value' do
      connect(range_columns)
      expect { helper.add_overlap_constraint(:meetings, :period, exclude_edges: true) }.to raise_error(ArgumentError, /not applicable to a range column/)
    end

    it 'rejects a non-range column' do
      connect([fake_column(:starts_at, :datetime, 'timestamp(6) without time zone')])
      expect { helper.add_overlap_constraint(:meetings, :starts_at) }.to raise_error(ArgumentError, /not a range column/)
    end

    it 'rejects a missing column' do
      connect(range_columns)
      expect { helper.add_overlap_constraint(:meetings, :nope) }.to raise_error(ArgumentError, /no column nope/)
    end
  end

  # PostgreSQL 18's temporal unique constraints: UNIQUE (scope, range WITHOUT OVERLAPS).
  # PostgreSQL enforces them as exclusion constraints (the docs: UNIQUE (id, r WITHOUT
  # OVERLAPS) behaves like EXCLUDE USING GIST (id WITH =, r WITH &&)), so the violation
  # class and RescueExclusionViolation keep working — verified against a real
  # PostgreSQL 18 server in spec_pg_18/.
  context 'without_overlaps: true (PostgreSQL 18+)' do
    let(:range_columns) do
      [fake_column(:period, :tstzrange, 'tstzrange'), fake_column(:user_id, :integer, 'integer', limit: 4)]
    end

    before do
      connect(range_columns)
      allow(helper.connection).to receive(:database_version).and_return(180_004)
    end

    it 'generates a temporal unique constraint instead of an exclusion constraint' do
      helper.add_overlap_constraint(:meetings, :period, scope: :user_id, without_overlaps: true)
      sql = helper.executed.first
      expect(sql).to include('ALTER TABLE "meetings"')
      expect(sql).to include('ADD CONSTRAINT "meetings_no_overlap"')
      expect(sql).to include('UNIQUE ("user_id", "period" WITHOUT OVERLAPS)')
      expect(helper.extensions).to eq ['btree_gist']
    end

    it 'raises on PostgreSQL versions before 18' do
      allow(helper.connection).to receive(:database_version).and_return(160_009)
      expect { helper.add_overlap_constraint(:meetings, :period, scope: :user_id, without_overlaps: true) }.to raise_error(ArgumentError, /PostgreSQL 18/)
    end

    it 'raises for the two-column form — WITHOUT OVERLAPS takes a range column, not an expression' do
      connect(datetime_columns)
      expect { helper.add_overlap_constraint(:meetings, :starts_at, :ends_at, scope: :user_id, without_overlaps: true) }.to raise_error(ArgumentError, /single range column/)
    end

    it 'raises without a scope — PostgreSQL requires an ordinary column before WITHOUT OVERLAPS' do
      expect { helper.add_overlap_constraint(:meetings, :period, without_overlaps: true) }.to raise_error(ArgumentError, /scope/)
    end
  end

  context 'adapter guard' do
    it 'raises NotImplementedError for add_overlap_constraint on non-PostgreSQL adapters' do
      helper.connection = double('connection', adapter_name: 'SQLite')
      expect { helper.add_overlap_constraint(:meetings, :starts_at, :ends_at) }.to raise_error(NotImplementedError, /PostgreSQL/)
    end

    it 'raises NotImplementedError for remove_overlap_constraint on non-PostgreSQL adapters' do
      helper.connection = double('connection', adapter_name: 'Mysql2')
      expect { helper.remove_overlap_constraint(:meetings) }.to raise_error(NotImplementedError, /PostgreSQL/)
    end
  end
end

describe 'ValidatesOverlap.exclusion_violation?' do
  it 'is false for a StatementInvalid without an exclusion-violation cause' do
    expect(ValidatesOverlap.exclusion_violation?(ActiveRecord::StatementInvalid.new('boom'))).to be false
  end

  it 'is false for arbitrary errors' do
    expect(ValidatesOverlap.exclusion_violation?(StandardError.new)).to be false
  end

  # Rails 8.1+ maps SQLSTATE 23P01 to its own error class; recognizing it does
  # not depend on the PG constant or on the cause chain surviving (e.g. JRuby)
  it 'recognizes ActiveRecord::ExclusionViolation even without a preserved cause' do
    stub_const('ActiveRecord::ExclusionViolation', Class.new(ActiveRecord::StatementInvalid))
    expect(ValidatesOverlap.exclusion_violation?(ActiveRecord::ExclusionViolation.new('boom'))).to be true
  end
end
