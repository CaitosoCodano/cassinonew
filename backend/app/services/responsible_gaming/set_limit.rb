module ResponsibleGaming
  class LimitError < StandardError; end

  # Sets or tightens a responsible-gaming limit.
  #
  # Player-initiated changes may only REDUCE a limit (never loosen it); once
  # reduced, a cooling-off period should be observed before it can be raised
  # again. Operators can override with `forced: true`, which is recorded in the
  # audit log.
  class SetLimit
    def self.call(user:, kind:, period: :daily, amount_minor: nil, duration_seconds: nil,
                  actor: nil, forced: false, reason: nil)
      existing = user.responsible_gaming_limits.find_by(kind: kind, period: period, active: true)

      if existing && !forced
        if amount_minor && existing.amount_minor && amount_minor > existing.amount_minor
          raise LimitError, "Limits can be reduced but not increased without operator approval."
        end
        if duration_seconds && existing.duration_seconds && duration_seconds > existing.duration_seconds
          raise LimitError, "Limits can be reduced but not increased without operator approval."
        end
      end

      limit = existing || user.responsible_gaming_limits.new(kind: kind, period: period)
      limit.assign_attributes(
        amount_minor: amount_minor.nil? ? limit.amount_minor : amount_minor,
        duration_seconds: duration_seconds.nil? ? limit.duration_seconds : duration_seconds,
        set_by: actor || user,
        active: true
      )
      limit.effective_from ||= Time.current
      limit.save!

      Audit::Record.call(
        actor: actor || user,
        action: existing ? "responsible_gaming.limit_updated" : "responsible_gaming.limit_set",
        auditable: limit,
        metadata: { kind: kind.to_s, period: period.to_s, forced: forced, reason: reason }
      )

      limit
    end
  end
end
