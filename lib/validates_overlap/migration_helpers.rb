module ValidatesOverlap
  # Migration helpers for a database-level overlap guarantee (PostgreSQL only).
  # The validation is check-then-act and cannot prevent double-booking under
  # concurrent writes; an exclusion constraint can (see the README).
  #
  # == Example:
  #   def up
  #     add_overlap_constraint :meetings, :starts_at, :ends_at, scope: :user_id
  #   end
  #   def down
  #     remove_overlap_constraint :meetings
  #   end
  module MigrationHelpers
    # Two scalar columns:  add_overlap_constraint :meetings, :starts_at, :ends_at, scope: :user_id
    # One range column:    add_overlap_constraint :meetings, :period, scope: :user_id
    #
    # scope:         column(s) compared with equality, mirroring the validator's :scope
    # name:          constraint name (default: <table>_no_overlap)
    # range_type:    PostgreSQL range type; inferred from the column types when omitted
    # exclude_edges: false (default) matches the validator's default — touching edges
    #                conflict; true builds half-open ranges, matching the validator's
    #                exclude_edges: [start, end] where touching is allowed.
    #                Not applicable to a range column (bounds live in the value)
    def add_overlap_constraint(table, starts_at, ends_at = nil, scope: [], name: nil, range_type: nil, exclude_edges: false)
      assert_postgresql!('add_overlap_constraint')
      scope_columns = Array(scope)
      enable_extension 'btree_gist' unless scope_columns.empty?
      elements = scope_columns.map { |column| "#{connection.quote_column_name(column)} WITH =" }
      if ends_at.nil?
        raise ArgumentError, 'validates_overlap: exclude_edges is not applicable to a range column — bound inclusivity is part of the range value itself' if exclude_edges
        assert_range_column!(table, starts_at)
        elements << "#{connection.quote_column_name(starts_at)} WITH &&"
      else
        range_type ||= overlap_range_type(table, starts_at, ends_at)
        bounds = exclude_edges ? '[)' : '[]'
        elements << "#{range_type}(#{connection.quote_column_name(starts_at)}, #{connection.quote_column_name(ends_at)}, '#{bounds}') WITH &&"
      end
      execute <<~SQL
        ALTER TABLE #{connection.quote_table_name(table)}
          ADD CONSTRAINT #{connection.quote_column_name(overlap_constraint_name(table, name))}
          EXCLUDE USING gist (#{elements.join(', ')})
      SQL
    end

    def remove_overlap_constraint(table, name: nil)
      assert_postgresql!('remove_overlap_constraint')
      execute "ALTER TABLE #{connection.quote_table_name(table)} DROP CONSTRAINT #{connection.quote_column_name(overlap_constraint_name(table, name))}"
    end

    private

    def assert_range_column!(table, column_name)
      column = connection.columns(table).find { |col| col.name == column_name.to_s }
      raise ArgumentError, "validates_overlap: no column #{column_name} on #{table}" unless column
      return if OverlapValidator::RANGE_COLUMN_TYPES.include?(column.type)
      raise ArgumentError, "validates_overlap: #{column_name} on #{table} is #{column.type.inspect}, not a range column — pass two columns for scalar range endpoints"
    end

    def overlap_constraint_name(table, name)
      name || "#{table}_no_overlap"
    end

    def assert_postgresql!(method_name)
      return if connection.adapter_name.match?(/postgresql/i)
      raise NotImplementedError, "validates_overlap: #{method_name} requires PostgreSQL (exclusion constraints are not available on #{connection.adapter_name})"
    end

    def overlap_range_type(table, starts_at, ends_at)
      columns = connection.columns(table).index_by(&:name)
      range_types = [starts_at, ends_at].map do |attr|
        column = columns[attr.to_s]
        raise ArgumentError, "validates_overlap: no column #{attr} on #{table}" unless column
        range_type_for(column)
      end.uniq
      raise ArgumentError, "validates_overlap: #{starts_at} and #{ends_at} on #{table} have different types; pass range_type: explicitly" if range_types.size > 1
      range_types.first
    end

    def range_type_for(column)
      case column.type
      when :datetime, :timestamp
        column.sql_type.match?(/with time zone/) ? 'tstzrange' : 'tsrange'
      when :date
        'daterange'
      when :integer
        column.limit == 8 ? 'int8range' : 'int4range'
      when :decimal
        'numrange'
      else
        raise ArgumentError, "validates_overlap: cannot infer a range type for #{column.name} (#{column.type}); pass range_type: explicitly"
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.include(ValidatesOverlap::MigrationHelpers)
end
