class SupportRequest < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true

  enum :category,
       { general: 0, account: 1, payments: 2, technical: 3,
         responsible_gaming: 4, complaint: 5 },
       default: :general

  enum :status, { open: 0, pending: 1, resolved: 2, closed: 3 }, default: :open
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }, default: :normal

  validates :subject, presence: true, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 5000 }

  scope :recent, -> { order(created_at: :desc) }
end
