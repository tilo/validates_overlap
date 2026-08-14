module ValidatesOverlap
  # Included into a model class when it declares an overlap validation
  module OverlappingRecords
    # The records whose ranges overlap this record's range, freshly queried on
    # every call and respecting the validation's options (scope, scoped_model,
    # shifts, exclude_edges, and self-exclusion for persisted records).
    # Returns an ActiveRecord::Relation — no records are loaded until used.
    def overlapping_records
      relations = self.class.validators.grep(OverlapValidator).map { |validator| validator.overlapping_records_for(self) }
      # a validation whose range value is nil conflicts with nothing — its empty
      # relation must not join the union: Relation#or keeps a NullRelation's
      # emptiness on Rails 6.1/7.0, which would hide the other validations' conflicts
      # (Relation#null_relation? arrived in 7.1; before that .none is detectable
      # by its extended NullRelation module, a constant removed in Rails 8)
      relations = relations.reject do |relation|
        relation.respond_to?(:null_relation?) ? relation.null_relation? : relation.extending_values.include?(ActiveRecord::NullRelation)
      end
      return self.class.none if relations.empty?
      models = relations.map(&:klass).uniq
      # Relation#or never compares the relations' classes — a union across models
      # would silently run one validation's conditions against the other's table
      raise ArgumentError, "overlapping_records cannot combine overlap validations that query different models (#{models.join(', ')}) — query each model separately" if models.size > 1
      relations.reduce(:or)
    end
  end
end
