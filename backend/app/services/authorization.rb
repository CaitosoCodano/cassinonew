# Server-side authorization checks.
#
# Every protected endpoint calls `authorize!(permission)` (see
# ApplicationController). Permissions are strings resolved from the user's
# role; they are never derived from anything the client sends.
module Authorization
  class NotAuthorized < StandardError
    attr_reader :permission

    def initialize(permission)
      @permission = permission
      super("Missing permission: #{permission}")
    end
  end

  module_function

  def authorize!(user, permission)
    return true if user&.permission?(permission)

    raise NotAuthorized, permission
  end

  def allowed?(user, permission)
    user&.permission?(permission) || false
  end
end
