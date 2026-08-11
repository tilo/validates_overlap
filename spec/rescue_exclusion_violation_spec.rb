require "#{File.dirname(__FILE__)}/spec_helper"

# Adapter-independent unit tests of the rescue logic: the violation is
# simulated with a stand-in PG::ExclusionViolation class. The behavior against
# a real PostgreSQL constraint is covered by spec_pg/.
describe ValidatesOverlap::RescueExclusionViolation do
  before do
    stub_const('PG', Module.new) unless defined?(PG)
    stub_const('PG::ExclusionViolation', Class.new(StandardError))
    stub_const('RescuedMeeting', Class.new(Meeting) do
      include ValidatesOverlap::RescueExclusionViolation
    end)
  end

  def exclusion_violation
    begin
      raise PG::ExclusionViolation, 'conflicting key value violates exclusion constraint'
    rescue PG::ExclusionViolation
      begin
        raise ActiveRecord::StatementInvalid, 'PG::ExclusionViolation: conflicting key value'
      rescue ActiveRecord::StatementInvalid => wrapped
        return wrapped
      end
    end
  end

  let(:meeting) { RescuedMeeting.new(starts_at: '2032-01-05'.to_date, ends_at: '2032-01-08'.to_date) }

  context 'when the database raises an exclusion violation during save' do
    before do
      allow(RescuedMeeting).to receive(:transaction).and_raise(exclusion_violation)
    end

    it 'save returns false and sets the overlap error where the validator would' do
      expect(meeting.save).to be false
      expect(meeting.errors[:starts_at]).to eq ['overlaps with another record']
    end

    it 'save! raises RecordInvalid with the error set' do
      expect { meeting.save! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(meeting.errors[:starts_at]).not_to be_empty
    end

    it 'adds the error to :base for a model without an overlap validator' do
      stub_const('BareRecord', Class.new(ActiveRecord::Base) do
        self.table_name = 'meetings'
        include ValidatesOverlap::RescueExclusionViolation
      end)
      allow(BareRecord).to receive(:transaction).and_raise(exclusion_violation)
      record = BareRecord.new(starts_at: '2032-01-05'.to_date, ends_at: '2032-01-08'.to_date)
      expect(record.save).to be false
      expect(record.errors[:base]).not_to be_empty
    end
  end

  context 'when the database raises a different error' do
    it 're-raises StatementInvalid errors that are not exclusion violations' do
      allow(RescuedMeeting).to receive(:transaction).and_raise(ActiveRecord::StatementInvalid.new('syntax error'))
      expect { meeting.save }.to raise_error(ActiveRecord::StatementInvalid, /syntax error/)
    end
  end

  context 'without any error' do
    it 'saves and validates normally' do
      expect(meeting.save).to be true
      overlapping = RescuedMeeting.new(starts_at: '2032-01-06'.to_date, ends_at: '2032-01-07'.to_date)
      expect(overlapping.save).to be false
      expect(overlapping.errors[:starts_at]).to eq ['overlaps with another record']
    end
  end
end
