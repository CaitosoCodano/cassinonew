module Ledger
  class Error < StandardError; end
  class WalletNotUsable < Error; end
  class InsufficientFunds < Error; end
  class InvalidAmount < Error; end

  # The single, authoritative entry point for changing a wallet balance.
  #
  # Guarantees:
  #   * runs inside a database transaction,
  #   * locks the wallet row (SELECT ... FOR UPDATE on PostgreSQL) so
  #     concurrent posts cannot interleave,
  #   * writes an immutable Transaction + append-only LedgerEntry,
  #   * is idempotent when an idempotency_key is supplied,
  #   * never allows a negative balance,
  #   * never trusts a balance provided by a client.
  #
  # Callers supply a signed amount_minor: positive credits the wallet,
  # negative debits it.
  class Post
    Result = Struct.new(:transaction, :wallet, :replayed, keyword_init: true) do
      def replayed?
        !!replayed
      end
    end

    def self.call(wallet:, amount_minor:, kind:, idempotency_key: nil, description: nil,
                  initiated_by: nil, metadata: {}, provider: nil, external_reference: nil)
      new(
        wallet: wallet,
        amount_minor: amount_minor,
        kind: kind,
        idempotency_key: idempotency_key,
        description: description,
        initiated_by: initiated_by,
        metadata: metadata,
        provider: provider,
        external_reference: external_reference
      ).call
    end

    def initialize(wallet:, amount_minor:, kind:, **options)
      @wallet = wallet
      @amount_minor = coerce_amount(amount_minor)
      @kind = kind
      @options = options
    end

    def call
      raise WalletNotUsable, "Wallet #{wallet.id} is not usable" unless wallet.usable?

      wallet.with_lock do
        replay = find_replay
        return replay if replay

        before = wallet.balance_minor
        after = before + amount_minor
        raise InsufficientFunds, "Insufficient funds" if after.negative?

        persist!(before: before, after: after)
      end
    rescue ActiveRecord::RecordNotUnique
      # A concurrent request won the idempotency race; return its result.
      existing = find_replay
      raise unless existing

      existing
    end

    private

    attr_reader :wallet, :amount_minor, :kind, :options

    def coerce_amount(value)
      integer = Integer(value)
      raise InvalidAmount, "Amount must not be zero" if integer.zero?
      if value.is_a?(Numeric) && integer != value
        raise InvalidAmount, "Amount must be a whole number of minor units"
      end

      integer
    rescue ArgumentError, TypeError
      raise InvalidAmount, "Amount must be an integer number of minor units"
    end

    def find_replay
      key = options[:idempotency_key]
      return nil if key.blank?

      existing = wallet.transactions.find_by(idempotency_key: key)
      return nil if existing.nil?

      Result.new(transaction: existing, wallet: wallet, replayed: true)
    end

    def persist!(before:, after:)
      transaction = nil
      entry = nil

      ActiveRecord::Base.transaction do
        wallet.update!(balance_minor: after)

        transaction = Transaction.create!(
          wallet: wallet,
          kind: kind,
          status: :completed,
          amount_minor: amount_minor,
          currency: wallet.currency,
          balance_before_minor: before,
          balance_after_minor: after,
          idempotency_key: options[:idempotency_key],
          description: options[:description],
          initiated_by: options[:initiated_by],
          provider: options[:provider],
          external_reference: options[:external_reference],
          metadata: options[:metadata] || {},
          processed_at: Time.current
        )

        entry = LedgerEntry.create!(
          wallet: wallet,
          financial_transaction: transaction,
          sequence: next_sequence,
          amount_minor: amount_minor,
          balance_after_minor: after,
          entry_type: kind.to_s,
          metadata: options[:metadata] || {},
          created_at: Time.current
        )
      end

      Result.new(transaction: transaction, wallet: wallet.reload, replayed: false)
    end

    def next_sequence
      (wallet.ledger_entries.maximum(:sequence) || 0) + 1
    end
  end
end
