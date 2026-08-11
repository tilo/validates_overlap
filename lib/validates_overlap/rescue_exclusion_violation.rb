module ValidatesOverlap
  # Opt-in companion to the exclusion constraint (see MigrationHelpers): in the
  # race window the validator cannot see, the constraint raises — this concern
  # rescues that and turns it into a normal validation failure: save returns
  # false with errors populated, save! raises ActiveRecord::RecordInvalid.
  #
  # NOTE: save runs in its own savepoint (requires_new) and the rescue sits
  # OUTSIDE it — a statement error aborts the innermost database transaction,
  # so it must be contained in a savepoint that is rolled back before the
  # rescue runs; otherwise a caller's surrounding transaction is left aborted.
  # (The same pattern the Rails guides document for rescuing RecordNotUnique.)
  #
  # == Example:
  #   class Meeting < ActiveRecord::Base
  #     validates :starts_at, :ends_at, overlap: { scope: :user_id }
  #     include ValidatesOverlap::RescueExclusionViolation
  #   end
  module RescueExclusionViolation
    def save(...)
      self.class.transaction(requires_new: true) { super }
    rescue ActiveRecord::StatementInvalid => e
      raise unless ValidatesOverlap.exclusion_violation?(e)
      add_overlap_error
      false
    end

    def save!(...)
      self.class.transaction(requires_new: true) { super }
    rescue ActiveRecord::StatementInvalid => e
      raise unless ValidatesOverlap.exclusion_violation?(e)
      add_overlap_error
      raise ActiveRecord::RecordInvalid, self
    end

    private

    # mirror the validator's error placement (message_title / message_content)
    def add_overlap_error
      validator = self.class.validators.grep(OverlapValidator).first
      if validator
        title = validator.options[:message_title]
        attribute = title.is_a?(Array) ? title.first : (title || validator.attributes.first)
        errors.add(attribute, validator.options[:message_content] || :overlap)
      else
        errors.add(:base, :overlap)
      end
    end
  end

  def self.exclusion_violation?(error)
    !!(defined?(PG::ExclusionViolation) && error.cause.is_a?(PG::ExclusionViolation))
  end
end
