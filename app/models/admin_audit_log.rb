# == Schema Information
#
# Table name: admin_audit_logs
#
#  id             :integer          not null, primary key
#  action         :string           not null
#  ip_address     :string
#  metadata       :text
#  resource_type  :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  admin_user_id  :integer          not null
#  resource_id    :integer
#  target_user_id :integer
#
# Indexes
#
#  index_admin_audit_logs_on_action          (action)
#  index_admin_audit_logs_on_admin_user_id   (admin_user_id)
#  index_admin_audit_logs_on_created_at      (created_at)
#  index_admin_audit_logs_on_target_user_id  (target_user_id)
#
# Foreign Keys
#
#  admin_user_id   (admin_user_id => users.id)
#  target_user_id  (target_user_id => users.id)
#
class AdminAuditLog < ApplicationRecord
  belongs_to :admin_user, class_name: 'User'
  belongs_to :target_user, class_name: 'User', optional: true
  belongs_to :resource, polymorphic: true, optional: true

  serialize :metadata, coder: JSON

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
end
