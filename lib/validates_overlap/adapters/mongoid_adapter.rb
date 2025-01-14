module ValidatesOverlap
  class MongoidAdapter < DatabaseAdapter
    # Initialize the query for the given record and options
    def initialize_query(record, options = {})
      scoped_model = options[:scoped_model].present? ? options[:scoped_model].constantize : record.class
      @scoped_model = scoped_model.all
      generate_overlap_conditions(record)
      add_attributes(record, options[:scope]) if options && options[:scope].present?
      add_query_options(options[:query_options]) if options && options[:query_options].present?
    end

    # Check if there exists at least one record in the database that overlaps with the current record
    def overlapped_exists?
      @scoped_model.where(@conditions).exists?
    end

    # Get the overlapped records from the database
    def get_overlapped
      @scoped_model.where(@conditions)
    end

    # Prepare attribute names to use in Mongoid conditions
    def attributes_to_mongoid(record)
      record.attributes.map { |attr| attribute_to_mongoid(attr, record) }
    end

    # Prepare attribute name to use in Mongoid conditions created in the form 'attribute_name'
    def attribute_to_mongoid(attr, record)
      attr.to_s.include?('.') ? attr : attr.to_s
    end

    # Generate Mongoid condition for time range overlap
    def generate_overlap_conditions(record)
      starts_at_attr, ends_at_attr = attributes_to_mongoid(record)
      main_condition = condition_string(starts_at_attr, ends_at_attr)
      primary_key_name = primary_key(record)
      key = primary_key_value(primary_key_name, record)
      if record.new_record?
        @conditions = main_condition
      else
        @conditions = main_condition.merge({ primary_key_name => { '$ne' => key } })
      end
    end

    # Return hash of values for overlap Mongoid condition
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

    def primary_key(record)
      record.class.primary_key
    end

    def primary_key_value(primary_key_name, record)
      record.send(primary_key_name)
    end

    def condition_string(starts_at_attr, ends_at_attr)
      except_option = Array(options[:exclude_edges]).map(&:to_s)
      starts_at_sign = except_option.include?(starts_at_attr.to_s.split('.').last) ? '$lt' : '$lte'
      ends_at_sign = except_option.include?(ends_at_attr.to_s.split('.').last) ? '$gt' : '$gte'
      {
        '$or' => [
          { ends_at_attr => { '$eq' => nil, ends_at_sign => :starts_at_value } },
          { starts_at_attr => { '$eq' => nil, starts_at_sign => :ends_at_value } }
        ]
      }
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
                   { '$eq' => nil }
                 elsif _value.is_a?(Array)
                   { '$in' => _value }
                 else
                   { '$eq' => _value }
      end

      @conditions[attr_name] = operator
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
      record.class.defined_enums[attr_name.to_s].present?
    end

    def add_query_options(methods)
      methods.each do |method_name, params|
        @scoped_model = @scoped_model.send(method_name.to_sym, *params)
      end
    end
  end
end
