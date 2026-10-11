module ResponsibleGaming
  # Places a self-exclusion (or cool-off) restriction on an account and revokes
  # every active session. Self-exclusions are enforced server-side: a restricted
  # player cannot log in, launch a game, or place a transaction.
  class SelfExclude
    def self.call(user:, duration_days: nil, reason: nil, actor: nil, cool_off: false, request: nil)
      ends_at = duration_days.present? ? duration_days.to_i.days.from_now : nil

      restriction = user.account_restrictions.create!(
        kind: cool_off ? :cool_off : :self_exclusion,
        status: :active,
        reason: reason,
        starts_at: Time.current,
        ends_at: ends_at,
        imposed_by: actor
      )

      user.sessions.active_now.find_each(&:revoke!)

      Audit::Record.call(
        actor: actor || user,
        action: cool_off ? "responsible_gaming.cool_off_started" : "responsible_gaming.self_exclusion_started",
        auditable: restriction,
        metadata: { ends_at: ends_at, reason: reason },
        request: request
      )

      restriction
    end
  end
end
