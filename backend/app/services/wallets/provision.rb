module Wallets
  # Creates the default wallets a user needs. A user always has exactly one
  # virtual-credit wallet; a real-money wallet is only created when real-money
  # functionality is explicitly enabled for the deployment.
  class Provision
    DEFAULT_VIRTUAL_CURRENCY = "VCR".freeze
    DEFAULT_REAL_CURRENCY = "EUR".freeze

    # Play-money granted to a brand-new account so a player can actually try a
    # game. This is promotional credit with no monetary value: it is posted
    # through the ledger as a `bonus` entry, never written straight onto the
    # balance, so the grant is visible in history and reconcilable.
    #
    # Override per environment with WELCOME_BONUS_MINOR. Set it to 0 to disable.
    WELCOME_BONUS_MINOR_DEFAULT = 100_000

    def self.call(user:, virtual_currency: DEFAULT_VIRTUAL_CURRENCY)
      virtual = user.wallets.virtual.find_or_create_by!(currency: virtual_currency.upcase) do |wallet|
        wallet.balance_minor = 0
        wallet.status = :active
      end

      if Platform.real_money_enabled?
        user.wallets.real.find_or_create_by!(currency: DEFAULT_REAL_CURRENCY) do |wallet|
          wallet.balance_minor = 0
          wallet.status = :active
        end
      end

      grant_welcome_bonus(virtual, user)
      virtual
    end

    def self.welcome_bonus_minor
      Integer(ENV.fetch("WELCOME_BONUS_MINOR", WELCOME_BONUS_MINOR_DEFAULT))
    rescue ArgumentError
      WELCOME_BONUS_MINOR_DEFAULT
    end

    def self.grant_welcome_bonus(wallet, user)
      amount = welcome_bonus_minor
      return if amount <= 0
      # Idempotent: the key means a second provision is a no-op replay.
      return if wallet.transactions.exists?(idempotency_key: welcome_bonus_key(wallet))

      Ledger::Post.call(
        wallet: wallet,
        amount_minor: amount,
        kind: :bonus,
        idempotency_key: welcome_bonus_key(wallet),
        description: "Welcome bonus",
        initiated_by: user,
        metadata: { source: "registration" }
      )
    rescue Ledger::Error => e
      # Never block registration over a promotional credit.
      Rails.logger.warn("Welcome bonus not granted: #{e.class} #{e.message}")
    end

    def self.welcome_bonus_key(wallet)
      "welcome_bonus:wallet:#{wallet.id}"
    end
  end
end