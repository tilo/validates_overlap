require 'active_support/i18n'

I18n.load_path << File.dirname(__FILE__) + '/locale/en.yml'

class OverlapValidator < ActiveModel::EachValidator
  def initialize(args)
    attributes_are_range(args[:attributes])

    super
  end

  # NOTE: Rails registers ONE validator instance per model class, shared by every
  # validation of that class (including concurrent ones) — so the query being
  # built must never be stored on the validator itself (issue #50)
  def validate(record)
    relation, sql_conditions, sql_values = initialize_query(record, options)
    if overlapped_exists?(relation, sql_conditions, sql_values)
      if options[:load_overlapped]
        record.instance_variable_set(:@overlapped_records, get_overlapped(relation, sql_conditions, sql_values))
      end

      if record.respond_to? attributes.first
        if options[:message_title].is_a?(Array)
          options[:message_title].each do |key|
            record.errors.add(key, options[:message_content] || :overlap)
          end
        else
          record.errors.add(options[:message_title] || attributes.first, options[:message_content] || :overlap)
        end
      else
        record.errors.add(options[:message_title] || :base, options[:message_content] || :overlap)
      end
    end
  end

  protected

  # Build the complete overlap query for this record.
  # return array in form [relation, sql_conditions, sql_values]
  def initialize_query(record, options = {})
    scoped_model = options[:scoped_model].present? ? options[:scoped_model].constantize : record.class
    relation = scoped_model.default_scoped
    sql_values = generate_overlap_sql_values(record)
    sql_conditions, primary_key_values = generate_overlap_sql_conditions(record, sql_values)
    sql_values = sql_values.merge(primary_key_values)
    sql_conditions, sql_values = add_attributes(record, options[:scope], sql_conditions, sql_values) if options && options[:scope].present?
    relation = add_query_options(relation, options[:query_options]) if options && options[:query_options].present?
    [relation, sql_conditions, sql_values]
  end

  # Check if exists at least one record in DB which is overlapped with current record
  def overlapped_exists?(relation, sql_conditions, sql_values)
    relation.exists?([sql_conditions, sql_values])
  end

  def get_overlapped(relation, sql_conditions, sql_values)
    relation.where([sql_conditions, sql_values])
  end

  # Resolve attributes values from record to use in sql conditions
  # return array in form ['2011-01-10', '2011-02-20']
  def resolve_values_from_attributes(record)
    attributes.map do |attr|
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
  # Prepare attribute names to use in sql conditions
  # return array in form ['meetings.starts_at', 'meetings.ends_at']
  def attributes_to_sql(record)
    attributes.map { |attr| attribute_to_sql(attr, record) }
  end

  # Prepare attribute name to use in sql conditions created in form 'table_name.attribute_name'
  def attribute_to_sql(attr, record)
    if attr.to_s.include?('.')
      attr
    else
      "#{record_table_name(record)}.#{attr}"
    end
  end

  # Get the table name for the record
  def record_table_name(record)
    record.class.table_name
  end

  # Check if the validation of time range is defined by 2 attributes
  def attributes_are_range(attributes)
    fail 'Validation of time range must be defined by 2 attributes' unless attributes.size == 2
  end

  def primary_key(record)
    record.class.primary_key
  end

  def primary_key_value(primary_key_name, record)
    record.send(primary_key_name)
  end

  # Generate sql condition for time range cross; a persisted record is excluded
  # from the comparison by its primary key, passed as a bind value
  # return array in form [sql_conditions, sql_values]
  def generate_overlap_sql_conditions(record, sql_values)
    starts_at_attr, ends_at_attr = attributes_to_sql(record)
    main_condition = condition_string(starts_at_attr, ends_at_attr, sql_values)
    if record.new_record?
      [main_condition, {}]
    else
      key = primary_key_value(primary_key(record), record)
      ["#{main_condition} AND #{record_table_name(record)}.#{primary_key(record)} != :record_primary_key_value", { record_primary_key_value: key }]
    end
  end

  # Return hash of values for overlap sql condition; a nil endpoint means the
  # record's range is open-ended on that side — no value is emitted for it and
  # condition_string drops the corresponding comparison
  # NOTE: shifts are only applied when configured — unconditionally adding a
  # default of 0 would raise a TypeError for non-numeric types such as String
  def generate_overlap_sql_values(record)
    starts_at_value, ends_at_value = resolve_values_from_attributes(record)
    start_shift = options && options[:start_shift]
    end_shift = options && options[:end_shift]
    starts_at_value += start_shift if starts_at_value && start_shift
    ends_at_value += end_shift if ends_at_value && end_shift
    sql_values = {}
    sql_values[:starts_at_value] = starts_at_value if starts_at_value
    sql_values[:ends_at_value] = ends_at_value if ends_at_value
    sql_values
  end

  # Return the condition string depend on exclude_edges option.
  # A comparison is only emitted for endpoints the record actually has: an
  # open-ended side matches every other record by definition, so its clause is
  # dropped (a record with both endpoints nil overlaps everything)
  def condition_string(starts_at_attr, ends_at_attr, sql_values)
    except_option = Array(options[:exclude_edges]).map(&:to_s)
    starts_at_sign = except_option.include?(starts_at_attr.to_s.split('.').last) ? '<' : '<='
    ends_at_sign = except_option.include?(ends_at_attr.to_s.split('.').last) ? '>' : '>='
    query = []
    query << "(#{ends_at_attr} IS NULL OR #{ends_at_attr} #{ends_at_sign} :starts_at_value)" if sql_values.key?(:starts_at_value)
    query << "(#{starts_at_attr} IS NULL OR #{starts_at_attr} #{starts_at_sign} :ends_at_value)" if sql_values.key?(:ends_at_value)
    query.empty? ? '1 = 1' : query.join(' AND ')
  end

  # Add attributes and values to sql conditions.
  # helps to use with scope options, so scope can be added as this forms :scope => "user_id" or :scope => ["user_id", "place_id"]
  # return array in form [sql_conditions, sql_values]
  def add_attributes(record, attrs, sql_conditions, sql_values)
    if attrs.is_a?(Array)
      attrs.each { |attr| sql_conditions, sql_values = add_attribute(record, attr, sql_conditions, sql_values) }
    elsif attrs.is_a?(Hash)
      attrs.each do |attr_name, value|
        sql_conditions, sql_values = add_attribute(record, attr_name, sql_conditions, sql_values, value)
      end
    else
      sql_conditions, sql_values = add_attribute(record, attrs, sql_conditions, sql_values)
    end
    [sql_conditions, sql_values]
  end

  # Add attribute and his value to sql condition
  # return array in form [sql_conditions, sql_values]
  def add_attribute(record, attr_name, sql_conditions, sql_values, value = nil)
    _value = resolve_attribute_value(record, attr_name, value)
    operator = if _value.nil?
                 ' IS NULL'
               elsif _value.is_a?(Array)
                 ' IN (:%s)'
               else
                 ' = :%s'
    end

    sql_conditions += " AND #{attribute_to_sql(attr_name, record)} #{operator}" % value_attribute_name(attr_name)
    sql_values = sql_values.merge(:"#{value_attribute_name(attr_name)}" => _value)
    [sql_conditions, sql_values]
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
        value = record.class.defined_enums[attr_name.to_s][value]
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

  # Allow to use scope, joins, includes methods before querying
  # == Example:
  # validates_overlap :date_from, :date_to, :query_options => {:includes => "visits"}
  # return the relation with the query options applied
  def add_query_options(relation, methods)
    methods.each do |method_name, params|
      relation = relation.send(method_name.to_sym, *params)
    end
    relation
  end
end
