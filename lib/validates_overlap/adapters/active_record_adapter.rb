module ValidatesOverlap
  class ActiveRecordAdapter < DatabaseAdapter
    # Initialize the query for the given record and options
    def initialize_query(record, options = {})
      scoped_model = options[:scoped_model].present? ? options[:scoped_model].constantize : record.class
      @scoped_model = scoped_model.default_scoped
      generate_overlap_sql_values(record)
      generate_overlap_sql_conditions(record)
      add_attributes(record, options[:scope]) if options && options[:scope].present?
      add_query_options(options[:query_options]) if options && options[:query_options].present?
    end

    # Check if there exists at least one record in the database that overlaps with the current record
    def overlapped_exists?
      @scoped_model.exists?([@sql_conditions, @sql_values])
    end

    # Get the overlapped records from the database
    def get_overlapped
      @scoped_model.where([@sql_conditions, @sql_values])
    end

    # Prepare attribute names to use in SQL conditions
    def attributes_to_sql(record)
      record.attributes.map { |attr| attribute_to_sql(attr, record) }
    end

    # Prepare attribute name to use in SQL conditions created in the form 'table_name.attribute_name'
    def attribute_to_sql(attr, record)
      if attr.to_s.include?('.')
        attr
      else
        "#{record_table_name(record)}.#{attr}"
      end
    end

    # Generate SQL condition for time range overlap
    def generate_overlap_sql_conditions(record)
      starts_at_attr, ends_at_attr = attributes_to_sql(record)
      main_condition = condition_string(starts_at_attr, ends_at_attr)
      primary_key_name = primary_key(record)
      key = primary_key_value(primary_key_name, record)
      if record.new_record?
        @sql_conditions = main_condition
      else
        @sql_conditions = "#{main_condition} AND #{record_table_name(record)}.#{primary_key(record)} !="
        @sql_conditions += key.is_a?(String) ? "'#{key}'" : key.to_s
      end
    end

    # Return hash of values for overlap SQL condition
    def generate_overlap_sql_values(record)
      starts_at_value, ends_at_value = resolve_values_from_attributes(record)
      starts_at_value += options.fetch(:start_shift) { 0 } if starts_at_value && options
      ends_at_value += options.fetch(:end_shift) { 0 } if ends_at_value && options
      @sql_values = { starts_at_value: starts_at_value || BEGIN_OF_UNIX_TIME, ends_at_value: ends_at_value || END_OF_UNIX_TIME }
    end

    private

    def resolve_values_from_attributes(record)
      record.attributes.map do |attr|
        if attr.to_s.include?('.')
          get_assoc_value(record, attr)
        else
          record.send(attr.to_sym)
        end
      end
    end

    def get_assoc_value(record, attr)
      assoc, attr_name = attr.to_s.split('.')
      assoc_name = assoc.singularize.to_sym
      assoc_obj = record.send(assoc_name) if record.respond_to?(assoc_name)
      (assoc_obj || record).send(attr_name.to_sym)
    end

    def record_table_name(record)
      record.class.table_name
    end

    def primary_key(record)
      record.class.primary_key
    end

    def primary_key_value(primary_key_name, record)
      record.send(primary_key_name)
    end

    def condition_string(starts_at_attr, ends_at_attr)
      except_option = Array(options[:exclude_edges]).map(&:to_s)
      starts_at_sign = except_option.include?(starts_at_attr.to_s.split('.').last) ? '<' : '<='
      ends_at_sign = except_option.include?(ends_at_attr.to_s.split('.').last) ? '>' : '>='
      query = []
      query << "(#{ends_at_attr} IS NULL OR #{ends_at_attr} #{ends_at_sign} :starts_at_value)"
      query << "(#{starts_at_attr} IS NULL OR #{starts_at_attr} #{starts_at_sign} :ends_at_value)"
      query.join(' AND ')
    end

    def add_attributes(record, attrs)
      if attrs.is_a?(Array)
        attrs.each { |attr| add_attribute(record, attr) }
      elsif attrs.is_a?(Hash)
        attrs.each do |attr_name, value|
          add_attribute(record, attr_name, value)
        end
      else
        add_attribute(record, attrs)
      end
    end

    def add_attribute(record, attr_name, value = nil)
      _value = resolve_attribute_value(record, attr_name, value)
      operator = if _value.nil?
                   ' IS NULL'
                 elsif _value.is_a?(Array)
                   ' IN (:%s)'
                 else
                   ' = :%s'
      end

      @sql_conditions += " AND #{attribute_to_sql(attr_name, record)} #{operator}" % value_attribute_name(attr_name)
      @sql_values.merge!(:"#{value_attribute_name(attr_name)}" => _value)
    end

    def value_attribute_name(attr_name)
      name = attr_name.to_s.include?('.') ? attr_name.to_s.gsub('.', '_') : attr_name.to_s
      name + '_value'
    end

    def resolve_attribute_value(record, attr_name, value = nil)
      if value
        value.is_a?(Proc) ? value.call(record) : value
      else
        value = record.read_attribute(attr_name)

        if is_enum_attribute?(record, attr_name)
          value = record.class.defined_enums[attr_name][value]
        end

        value
      end
    end

    def is_enum_attribute?(record, attr_name)
      implement_enum? && record.class.defined_enums[attr_name.to_s].present?
    end

    def implement_enum?
      (ActiveRecord::VERSION::MAJOR >= 5) || (ActiveRecord::VERSION::MAJOR > 4 && ActiveRecord::VERSION::MINOR > 1)
    end

    def add_query_options(methods)
      methods.each do |method_name, params|
        @scoped_model = @scoped_model.send(method_name.to_sym, *params)
      end
    end
  end
end
