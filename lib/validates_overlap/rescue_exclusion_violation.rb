module ValidatesOverlap
  # Opt-in companion to the exclusion constraint (see MigrationHelpers): in the
  # race window the validator cannot see, the constraint raises — this concern
  # rescues that and turns it into a normal validation failure: save returns
  # false with errors populated, save! raises ActiveRecord::RecordInvalid.
  #
  # NOTE: a statement error aborts the innermost database transaction, so when
  # the caller already has a joinable transaction open, save runs in its own
  # savepoint (requires_new) with the rescue OUTSIDE it — otherwise the rescue
  # would leave the caller's transaction in the aborted state. (The same
  # pattern the Rails guides document for rescuing RecordNotUnique.)
  # In every other situation the wrapper must NOT be added: ActiveRecord's own
  # save transaction already contains the error there, and an extra wrapper at
  # top level makes the save transaction JOIN it — silently swallowing the
  # rollback a halted callback (throw :abort) relies on.
  #
  # == Example:
  #   class Meeting < ActiveRecord::Base
  #     validates :starts_at, :ends_at, overlap: { scope: :user_id }
  #     include ValidatesOverlap::RescueExclusionViolation
  #   end
  module RescueExclusionViolation
    def save(...)
      contain_exclusion_violation { super }
    rescue ActiveRecord::StatementInvalid => e
      raise unless ValidatesOverlap.exclusion_violation?(e)
      add_overlap_error
      false
    end

    def save!(...)
      contain_exclusion_violation { super }
    rescue ActiveRecord::StatementInvalid => e
      raise unless ValidatesOverlap.exclusion_violation?(e)
      add_overlap_error
      raise ActiveRecord::RecordInvalid, self
    end

    private

    # See the NOTE above: the savepoint exists to protect a caller's open
    # joinable transaction, and only PostgreSQL can raise the violation this
    # concern rescues — everywhere else the wrapper would be pure overhead
    # (a SAVEPOINT/RELEASE round-trip per save) or actively harmful (the
    # swallowed rollback-on-abort at top level)
    def contain_exclusion_violation(&block)
      connection = self.class.connection
      if connection.adapter_name.match?(/postgresql/i) && connection.transaction_open? && connection.current_transaction.joinable?
        self.class.transaction(requires_new: true, &block)
      else
        yield
      end
    end

    # mirror the validator's error placement exactly (add_overlap_error on the
    # validator handles array titles and the :base fallback); with several
    # overlap validations the database does not tell us which constraint
    # fired — the first validator's message settings are used
    def add_overlap_error
      validator = self.class.validators.grep(OverlapValidator).first
      if validator
        validator.add_overlap_error(self)
      else
        errors.add(:base, :overlap)
      end
    end
  end

  def self.exclusion_violation?(error)
    return true if defined?(ActiveRecord::ExclusionViolation) && error.is_a?(ActiveRecord::ExclusionViolation)
    !!(defined?(PG::ExclusionViolation) && error.cause.is_a?(PG::ExclusionViolation))
  end
end
