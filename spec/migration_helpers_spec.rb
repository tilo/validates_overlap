require "#{File.dirname(__FILE__)}/spec_helper"

# Adapter-independent contracts (the PostgreSQL behavior itself is covered by
# spec_pg/, run with DB=postgres)
describe ValidatesOverlap::MigrationHelpers do
  let(:helper) do
    Class.new do
      include ValidatesOverlap::MigrationHelpers
      attr_accessor :connection
    end.new
  end

  it 'raises NotImplementedError for add_overlap_constraint on non-PostgreSQL adapters' do
    helper.connection = double('connection', adapter_name: 'SQLite')
    expect { helper.add_overlap_constraint(:meetings, :starts_at, :ends_at) }.to raise_error(NotImplementedError, /PostgreSQL/)
  end

  it 'raises NotImplementedError for remove_overlap_constraint on non-PostgreSQL adapters' do
    helper.connection = double('connection', adapter_name: 'Mysql2')
    expect { helper.remove_overlap_constraint(:meetings) }.to raise_error(NotImplementedError, /PostgreSQL/)
  end
end

describe 'ValidatesOverlap.exclusion_violation?' do
  it 'is false for a StatementInvalid without an exclusion-violation cause' do
    expect(ValidatesOverlap.exclusion_violation?(ActiveRecord::StatementInvalid.new('boom'))).to be false
  end

  it 'is false for arbitrary errors' do
    expect(ValidatesOverlap.exclusion_violation?(StandardError.new)).to be false
  end
end
