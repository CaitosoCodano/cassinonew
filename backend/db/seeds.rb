# Seed data contains ONLY real configuration the platform needs to function:
# roles, feature flags and platform settings. It never creates fake users,
# balances, transactions, games or activity.
#
# An initial administrator is created only when ADMIN_EMAIL and ADMIN_PASSWORD
# are supplied via the environment -- credentials are never hard-coded.

puts "Seeding roles..."
[
  { name: Role::PLAYER,  description: "Standard player account", permissions: Role::PLAYER_PERMISSIONS,  system: true },
  { name: Role::SUPPORT, description: "Customer support agent",  permissions: Role::SUPPORT_PERMISSIONS, system: true },
  { name: Role::ADMIN,   description: "Platform administrator",  permissions: Role::ADMIN_PERMISSIONS,   system: true }
].each do |attrs|
  role = Role.find_or_initialize_by(name: attrs[:name])
  role.update!(attrs)
end

puts "Seeding feature flags..."
[
  { key: "games_lobby",      enabled: true,  description: "Expose the games lobby navigation." },
  { key: "virtual_credits",  enabled: true,  description: "Enable virtual-credit wallets." },
  { key: "real_money",       enabled: false, description: "Master switch for real-money functionality (requires legal + payment integration)." },
  { key: "self_exclusion",   enabled: true,  description: "Allow players to self-exclude." },
  { key: "support_requests", enabled: true,  description: "Allow support request submission." },
  { key: "admin_panel",      enabled: true,  description: "Expose the administration area." },
  { key: "registrations",    enabled: true,  description: "Allow new account registration." }
].each do |attrs|
  FeatureFlag.find_or_initialize_by(key: attrs[:key]).update!(attrs)
end

puts "Seeding platform settings..."
[
  { key: "minimum_age",      value: 18,    category: "compliance",          description: "Minimum age for account registration." },
  { key: "cool_off_hours",   value: 24,    category: "responsible_gaming",  description: "Default cool-off duration in hours." },
  { key: "self_exclusion_min_days", value: 1, category: "responsible_gaming", description: "Minimum self-exclusion duration in days." },
  { key: "default_virtual_currency", value: "VCR", category: "wallet",      description: "Default virtual-credit currency code." },
  { key: "default_real_currency",    value: "EUR", category: "wallet",      description: "Default real-money currency code (if ever enabled)." },
  { key: "registration_open", value: true, category: "platform",            description: "Whether new registrations are accepted." }
].each do |attrs|
  setting = PlatformSetting.find_or_initialize_by(key: attrs[:key])
  setting.assign_attributes(attrs)
  setting.editable = true
  setting.save!
end

# The shipped catalogue. These are real configuration records pointing at maths
# classes that exist in the codebase -- no placeholder title, no invented
# provider. A deployment that wants a different line-up flips a title to
# `inactive` from the admin area.
puts "Seeding game catalogue..."
provider = GameProvider.find_or_initialize_by(slug: "internal")
provider.assign_attributes(
  name: "Luminara Originals",
  status: :active,
  adapter_class: nil,
  description: "First-party titles served by the platform's own maths engine."
)
provider.save!

[
  { slug: "dragon_fortune", name: "Dragon Fortune" },
  { slug: "buffalo_fortune", name: "Buffalo Fortune" }
].each do |attrs|
  # Only register a title whose maths actually exists, so the lobby can never
  # offer something the engine cannot resolve.
  next unless Games::Registry.registered?(attrs[:slug])

  game = Game.find_or_initialize_by(slug: attrs[:slug], game_provider_id: provider.id)
  game.assign_attributes(
    name: attrs[:name],
    category: :slot,
    status: :active,
    min_bet_minor: 100,
    max_bet_minor: 1_000_000,
    supported_currencies: ["VCR"],
    description: "Play-money title. Outcomes are decided server-side from a recorded seed."
  )
  game.save!
end

# Game maths and payout settings, so a fresh deployment is playable at once.
puts "Seeding game configuration..."
Games::Config.update!(
  "user_rtp_percent" => Games::Config::DEFAULTS["user_rtp_percent"],
  "bonus_trigger_prob_percent" => Games::Config::DEFAULTS["bonus_trigger_prob_percent"],
  "buy_bonus_enabled" => Games::Config::DEFAULTS["buy_bonus_enabled"],
  "buy_bonus_cost_multiple" => Games::Config::DEFAULTS["buy_bonus_cost_multiple"],
  "min_bet_minor" => Games::Config::DEFAULTS["min_bet_minor"],
  "max_bet_minor" => Games::Config::DEFAULTS["max_bet_minor"],
  "default_bet_minor" => Games::Config::DEFAULTS["default_bet_minor"]
)

admin_email = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]

if admin_email.present? && admin_password.present?
  puts "Creating/updating administrator #{admin_email}..."
  admin = User.find_or_initialize_by(email: admin_email.downcase)
  admin.role = Role.find_by!(name: Role::ADMIN)
  admin.password = admin_password
  admin.status = :active
  admin.email_verified_at ||= Time.current
  admin.save!
  admin.create_profile! unless admin.profile
  Wallets::Provision.call(user: admin)
  puts "Administrator ready."
else
  puts "Skipping admin bootstrap: set ADMIN_EMAIL and ADMIN_PASSWORD to create the first administrator."
end

puts "Seed complete."
