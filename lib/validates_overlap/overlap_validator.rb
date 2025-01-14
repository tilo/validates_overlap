require 'active_support/i18n'
require 'validates_overlap/database_adapter'
require 'validates_overlap/adapters/active_record_adapter'
require 'validates_overlap/adapters/mongoid_adapter'

I18n.load_path << File.dirname(__FILE__) + '/locale/en.yml'

class OverlapValidator < ActiveModel::EachValidator
  BEGIN_OF_UNIX_TIME = Time.at(-2_147_483_648).to_datetime
  END_OF_UNIX_TIME = Time.at(2_147_483_648).to_datetime

  attr_accessor :database_adapter

  def initialize(args)
    attributes_are_range(args[:attributes])
    super
    @database_adapter = determine_database_adapter(args[:attributes].first)
  end

  def validate(record)
    database_adapter.initialize_query(record, options)
    if database_adapter.overlapped_exists?
      if options[:load_overlapped]
        record.instance_variable_set(:@overlapped_records, database_adapter.get_overlapped)
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

  def determine_database_adapter(attribute)
    if attribute.to_s.include?('.')
      ValidatesOverlap::MongoidAdapter.new
    else
      ValidatesOverlap::ActiveRecordAdapter.new
    end
  end

  def attributes_are_range(attributes)
    fail 'Validation of time range must be defined by 2 attributes' unless attributes.size == 2
  end
end
