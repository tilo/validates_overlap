module ValidatesOverlap
  class DatabaseAdapter
    # Initialize the query for the given record and options
    def initialize_query(record, options = {})
      raise NotImplementedError, 'Subclasses must implement the initialize_query method'
    end

    # Check if there exists at least one record in the database that overlaps with the current record
    def overlapped_exists?
      raise NotImplementedError, 'Subclasses must implement the overlapped_exists? method'
    end

    # Get the overlapped records from the database
    def get_overlapped
      raise NotImplementedError, 'Subclasses must implement the get_overlapped method'
    end

    # Prepare attribute names to use in SQL conditions
    def attributes_to_sql(record)
      raise NotImplementedError, 'Subclasses must implement the attributes_to_sql method'
    end

    # Prepare attribute name to use in SQL conditions created in the form 'table_name.attribute_name'
    def attribute_to_sql(attr, record)
      raise NotImplementedError, 'Subclasses must implement the attribute_to_sql method'
    end

    # Generate SQL condition for time range overlap
    def generate_overlap_sql_conditions(record)
      raise NotImplementedError, 'Subclasses must implement the generate_overlap_sql_conditions method'
    end

    # Return hash of values for overlap SQL condition
    def generate_overlap_sql_values(record)
      raise NotImplementedError, 'Subclasses must implement the generate_overlap_sql_values method'
    end
  end
end
