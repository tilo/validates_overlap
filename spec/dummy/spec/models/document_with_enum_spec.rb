require "#{File.dirname(__FILE__)}/../../../spec_helper"

describe DocumentWithEnum do
  context '2 overlapping documents with same kind' do
    it 'are invalid' do

      document_1 = FactoryBot.create(
        :document_with_enum,
        kind: :draft,
        valid_from: '2011-01-05'.to_date,
        valid_until: '2011-01-08'.to_date
      )

      document_2 = FactoryBot.build(
        :document_with_enum,
        kind: :draft,
        valid_from: '2011-01-06'.to_date,
        valid_until: '2011-01-07'.to_date
      )

      expect(document_2).not_to be_valid
      expect(document_2.errors[:valid_from]).to eq ["overlaps with another record"]
    end
  end

  context '2 overlapping documents with different kind' do
    it 'are valid' do
      document_1 = FactoryBot.create(
        :document_with_enum,
        kind: :draft,
        valid_from: '2011-01-05'.to_date,
        valid_until: '2011-01-08'.to_date
      )

      document_2 = FactoryBot.build(
        :document_with_enum,
        kind: :contract,
        valid_from: '2011-01-06'.to_date,
        valid_until: '2011-01-07'.to_date
      )

      expect(document_2).to be_valid
    end
  end

  describe '#kind' do
    it 'save and read attribute properly' do
      docuemnt = FactoryBot.create(:document_with_enum, kind: :contract)
      docuemnt.reload
      expect(docuemnt.kind.to_s).to eq "contract"
    end
  end
end
