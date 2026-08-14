raise 'PostgreSQL-only specs: run with DB=postgres bundle exec rspec spec_pg' unless ENV['DB'] == 'postgres'
ENV['PG_SPECS'] = '1'

require "#{File.dirname(__FILE__)}/../spec/spec_helper"

# Native PostgreSQL range columns: `validates :period, overlap: ...` on a single
# range-typed column, compared with PostgreSQL's && operator. The semantics are
# deliberately inherited from PostgreSQL's range algebra, so the validation and
# an exclusion constraint (EXCLUDE ... WITH &&) can never disagree.
describe 'overlap validation on a range column' do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.drop_table :pg_slots, if_exists: true
    connection.create_table :pg_slots do |t|
      t.tstzrange :period
      t.integer :user_id
    end
    stub_const('PgSlot', Class.new(ActiveRecord::Base) do
      self.table_name = 'pg_slots'
      validates :period, overlap: { scope: 'user_id' }
    end)
  end

  after do
    connection.drop_table :pg_slots, if_exists: true
  end

  def t(hour)
    Time.utc(2030, 1, 1, hour)
  end

  context 'basic overlap semantics' do
    before do
      PgSlot.create!(user_id: 1, period: t(10)...t(12))
    end

    it 'is not valid if the ranges overlap for the same scope' do
      slot = PgSlot.new(user_id: 1, period: t(11)...t(13))
      expect(slot).not_to be_valid
      expect(slot.errors[:period]).to eq ['overlaps with another record']
    end

    it 'is valid if the ranges are disjoint' do
      expect(PgSlot.new(user_id: 1, period: t(13)...t(14))).to be_valid
    end

    it 'is valid if the overlap belongs to another scope' do
      expect(PgSlot.new(user_id: 2, period: t(11)...t(13))).to be_valid
    end

    it 'does not conflict with itself once persisted' do
      slot = PgSlot.first
      slot.user_id = 1
      expect(slot).to be_valid
    end
  end

  context 'edge behavior comes from the stored bounds, not from options' do
    it 'half-open ranges may touch' do
      PgSlot.create!(user_id: 1, period: t(10)...t(12))
      expect(PgSlot.new(user_id: 1, period: t(12)...t(14))).to be_valid
    end

    it 'closed ranges conflict when touching' do
      PgSlot.create!(user_id: 1, period: t(10)..t(12))
      expect(PgSlot.new(user_id: 1, period: t(12)..t(14))).not_to be_valid
    end
  end

  context 'NULL and special range values (PostgreSQL range algebra inherited)' do
    before do
      PgSlot.create!(user_id: 1, period: t(10)...t(12))
    end

    it 'a NULL range means no range and conflicts with nothing' do
      expect(PgSlot.new(user_id: 1, period: nil)).to be_valid
    end

    it 'a stored NULL range does not conflict with anything' do
      PgSlot.delete_all
      PgSlot.create!(user_id: 1, period: nil)
      expect(PgSlot.new(user_id: 1, period: t(10)...t(12))).to be_valid
    end

    it 'the explicit unbounded range conflicts with everything' do
      slot = PgSlot.new(user_id: 1)
      slot.period = Range.new(nil, nil)
      expect(slot).not_to be_valid
    end

    it 'an open-ended range conflicts with later ranges' do
      slot = PgSlot.new(user_id: 1, period: Range.new(t(11), nil))
      expect(slot).not_to be_valid
    end
  end

  context 'overlapping_records' do
    it 'returns the conflicting records as a relation, freshly computed' do
      existing = PgSlot.create!(user_id: 1, period: t(10)...t(12))
      slot = PgSlot.new(user_id: 1, period: t(11)...t(13))
      expect(slot.overlapping_records).to eq [existing]

      slot.period = t(13)...t(14)
      expect(slot.overlapping_records).to be_empty
    end

    it 'returns an empty relation for a NULL range' do
      slot = PgSlot.new(user_id: 1, period: nil)
      expect(slot.overlapping_records).to be_a(ActiveRecord::Relation)
      expect(slot.overlapping_records).to be_empty
    end
  end

  context 'declaration errors' do
    it 'raises at validate time when the single attribute is not a range column' do
      stub_const('BadSlot', Class.new(ActiveRecord::Base) do
        self.table_name = 'pg_slots'
        validates :user_id, overlap: true
      end)
      expect { BadSlot.new(user_id: 1).valid? }.to raise_error(OverlapValidator::UnsupportedColumnType, /range column/)
    end

    it 'rejects exclude_edges for a range column at declaration time' do
      expect {
        Class.new(ActiveRecord::Base) do
          self.table_name = 'pg_slots'
          validates :period, overlap: { exclude_edges: 'period' }
        end
      }.to raise_error(ArgumentError, /edge inclusivity .* range value|not applicable/i)
    end

    it 'rejects shifts for a range column at declaration time' do
      expect {
        Class.new(ActiveRecord::Base) do
          self.table_name = 'pg_slots'
          validates :period, overlap: { start_shift: 1 }
        end
      }.to raise_error(ArgumentError, /not applicable/i)
    end
  end

  context 'other range types' do
    it 'works for daterange columns' do
      connection.create_table(:pg_seasons2) { |t| t.daterange :span }
      stub_const('PgSeason', Class.new(ActiveRecord::Base) do
        self.table_name = 'pg_seasons2'
        validates :span, overlap: true
      end)
      PgSeason.create!(span: Date.new(2030, 1, 1)...Date.new(2030, 4, 1))
      expect(PgSeason.new(span: Date.new(2030, 3, 1)...Date.new(2030, 6, 1))).not_to be_valid
      expect(PgSeason.new(span: Date.new(2030, 4, 1)...Date.new(2030, 6, 1))).to be_valid
    ensure
      connection.drop_table :pg_seasons2, if_exists: true
    end

    it 'works for int4range columns' do
      connection.create_table(:pg_blocks2) { |t| t.int4range :numbers }
      stub_const('PgBlock', Class.new(ActiveRecord::Base) do
        self.table_name = 'pg_blocks2'
        validates :numbers, overlap: true
      end)
      PgBlock.create!(numbers: 100...200)
      expect(PgBlock.new(numbers: 150...250)).not_to be_valid
      expect(PgBlock.new(numbers: 200...300)).to be_valid
    ensure
      connection.drop_table :pg_blocks2, if_exists: true
    end
  end
end
