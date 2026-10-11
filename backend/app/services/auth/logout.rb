module Auth
  # Revokes the current session (and optionally all sessions for the user).
  class Logout
    def self.call(session: nil, user: nil, all: false)
      if all && user
        user.sessions.active_now.find_each(&:revoke!)
      elsif session
        session.revoke!
      end
      true
    end
  end
end
