class AdminAuditLog < ApplicationRecord
  belongs_to :admin_user, class_name: 'User'
  belongs_to :target_user, class_name: 'User', optional: true
  belongs_to :resource, polymorphic: true, optional: true

  serialize :metadata, coder: JSON

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
end
