class Transaction < ApplicationRecord
  belongs_to :wallet
  belongs_to :initiated_by, class_name: "User", optional: true

  has_many :ledger_entries, dependent: :restrict_with_error

  # Financial vocabulary shared by the ledger and the wallet service.
  enum :kind,
       { deposit: 0, withdrawal: 1, bet: 2, win: 3, adjustment: 4,
         transfer: 5, refund: 6, bonus: 7, reversal: 8 },
       default: :deposit

  # A transaction is created as pending and becomes completed or failed inside
  # the same database transaction that writes the ledger entry. Failed
  # transactions never touch the balance.
  enum :status,
       { pending: 0, completed: 1, failed: 2, reversed: 3, cancelled: 4 },
       default: :pending

  validates :amount_minor, numericality: { only_integer: true }
  validates :currency, presence: true, format: { with: /\A[A-Z0-9]{3}\z/ }
  validates :balance_before_minor, :balance_after_minor, numericality: { only_integer: true }

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: :completed) }

  # True when the operation credits the wallet.
  def credit?
    amount_minor.positive?
  end

  def debit?
    amount_minor.negative?
  end
end
