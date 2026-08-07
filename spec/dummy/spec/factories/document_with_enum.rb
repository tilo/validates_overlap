FactoryBot.define do
  factory :document_with_enum do
    valid_from { '2011-01-05'.to_date }
    valid_until { '2011-01-08'.to_date }
    kind { :draft }
  end

  factory :document_with_symbol_scoped_enum, class: DocumentWithSymbolScopedEnum do
    valid_from { '2011-01-05'.to_date }
    valid_until { '2011-01-08'.to_date }
    kind { :draft }
  end
end
