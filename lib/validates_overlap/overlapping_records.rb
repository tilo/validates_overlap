module ValidatesOverlap
  # Included into a model class when it declares an overlap validation
  module OverlappingRecords
    # The records whose ranges overlap this record's range, freshly queried on
    # every call and respecting the validation's options (scope, scoped_model,
    # shifts, exclude_edges, and self-exclusion for persisted records).
    # Returns an ActiveRecord::Relation — no records are loaded until used.
    def overlapping_records
      self.class.validators.grep(OverlapValidator).map { |validator| validator.overlapping_records_for(self) }.reduce(:or)
    end
  end
end
