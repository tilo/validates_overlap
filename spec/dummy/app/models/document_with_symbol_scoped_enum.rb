# Same table and validation as DocumentWithEnum, but the scope names the enum
# attribute as a SYMBOL — regression model for issue #54 (PR #55)
class DocumentWithSymbolScopedEnum < ActiveRecord::Base
  self.table_name = 'documents_with_enum'
  KINDS = [:contract, :fact, :draft]

  if ActiveRecord::VERSION::MAJOR >= 7
    enum :kind, KINDS
  else
    # Rails 6.x only understands the keyword form (removed in Rails 8)
    enum kind: KINDS
  end

  validates :valid_from, :valid_until, overlap: {
    exclude_edges: ['valid_from', 'valid_until'],
    scope: [:kind]
  }
end
