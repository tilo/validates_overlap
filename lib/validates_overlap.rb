require_relative 'validates_overlap/version'
require_relative 'validates_overlap/overlapping_records'
require_relative 'validates_overlap/overlap_validator'
require_relative 'validates_overlap/migration_helpers'
require_relative 'validates_overlap/rescue_exclusion_violation'

module ValidatesOverlap
  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('2.0', 'validates_overlap')
  end
end
