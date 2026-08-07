require "#{File.dirname(__FILE__)}/../../../spec_helper"

# Regression for issue #54: a scope naming an enum attribute as a SYMBOL used to
# crash with "undefined method '[]' for nil" (defined_enums is keyed by strings)
describe DocumentWithSymbolScopedEnum do
  context '2 overlapping documents with same kind' do
    it 'are invalid' do
      FactoryBot.create(:document_with_symbol_scoped_enum, kind: :draft)

      document = FactoryBot.build(
        :document_with_symbol_scoped_enum,
        kind: :draft,
        valid_from: '2011-01-06'.to_date,
        valid_until: '2011-01-07'.to_date
      )

      expect(document).not_to be_valid
      expect(document.errors[:valid_from]).to eq ['overlaps with another record']
    end
  end

  context '2 overlapping documents with different kind' do
    it 'are valid' do
      FactoryBot.create(:document_with_symbol_scoped_enum, kind: :draft)

      document = FactoryBot.build(
        :document_with_symbol_scoped_enum,
        kind: :contract,
        valid_from: '2011-01-06'.to_date,
        valid_until: '2011-01-07'.to_date
      )

      expect(document).to be_valid
    end
  end
end
