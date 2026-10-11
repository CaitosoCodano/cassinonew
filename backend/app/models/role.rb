class Role < ApplicationRecord
  # Canonical roles. Permissions are string scopes checked server-side by
  # ApplicationPolicy / the authorization concern. "*" grants everything.
  PLAYER = "player".freeze
  SUPPORT = "support".freeze
  ADMIN = "admin".freeze

  SYSTEM_ROLES = [PLAYER, SUPPORT, ADMIN].freeze

  PLAYER_PERMISSIONS = %w[profile.read profile.write].freeze

  SUPPORT_PERMISSIONS = (
    PLAYER_PERMISSIONS + %w[
      users.read support.read support.write audit.read
    ]
  ).freeze

  ADMIN_PERMISSIONS = %w[*].freeze

  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  def permission?(permission)
    return false if permission.blank?

    permissions.include?("*") || permissions.include?(permission)
  end

  def admin?
    name == ADMIN
  end

  def self.default_by_name(name)
    find_by(name: name)
  end
end
