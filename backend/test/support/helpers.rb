# Shared helpers for building real domain records in tests.
module SupportHelpers
  DEFAULT_PASSWORD = "C0rrect-Horse-Battery-42".freeze

  def player_role
    @player_role ||= Role.find_or_create_by!(name: Role::PLAYER) do |role|
      role.description = "Standard player account"
      role.permissions = Role::PLAYER_PERMISSIONS
      role.system = true
    end
  end

  def support_role
    @support_role ||= Role.find_or_create_by!(name: Role::SUPPORT) do |role|
      role.description = "Customer support agent"
      role.permissions = Role::SUPPORT_PERMISSIONS
      role.system = true
    end
  end

  def admin_role
    @admin_role ||= Role.find_or_create_by!(name: Role::ADMIN) do |role|
      role.description = "Platform administrator"
      role.permissions = Role::ADMIN_PERMISSIONS
      role.system = true
    end
  end

  def create_user(email: nil, password: DEFAULT_PASSWORD, role: player_role, status: :active,
                  verified: true, marketing_opt_in: false, **attrs)
    email ||= "player-#{SecureRandom.hex(6)}@example.com"
    user = User.new(
      email: email,
      password: password,
      password_confirmation: password,
      role: role,
      status: status
    )
    user.email_verified_at = Time.current if verified
    user.assign_attributes(attrs)
    user.save!
    user.create_profile!(locale: "en", marketing_opt_in: marketing_opt_in) unless user.profile
    Wallets::Provision.call(user: user)
    user
  end

  def create_admin(email: nil, **attrs)
    create_user(email: email || "admin-#{SecureRandom.hex(6)}@example.com", role: admin_role, **attrs)
  end

  def create_provider(slug: "fake-provider", name: "Fake Provider", adapter_class: "TestAdapters::FakeAdapter",
                      status: :active, **attrs)
    GameProvider.create!(
      slug: slug,
      name: name,
      adapter_class: adapter_class,
      status: status,
      integration_version: "1.0.0",
      **attrs
    )
  end

  def create_game(provider:, slug: "demo-game", name: "Demo Game", category: :slot,
                  status: :active, supported_currencies: %w[VCR], **attrs)
    Game.create!(
      game_provider: provider,
      slug: slug,
      name: name,
      category: category,
      status: status,
      supported_currencies: supported_currencies,
      **attrs
    )
  end

  def ensure_roles!
    player_role
    support_role
    admin_role
  end

  # --- Integration helpers ---------------------------------------------------

  def login_as(user, password: DEFAULT_PASSWORD)
    post "/api/v1/auth/login", params: { email: user.email, password: password }, as: :json
    assert_response :created
  end

  def json_body
    JSON.parse(response.body)
  end
end