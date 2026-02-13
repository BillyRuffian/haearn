# == Schema Information
#
# Table name: notifications
#
#  id         :integer          not null, primary key
#  dedupe_key :string           not null
#  kind       :string           not null
#  message    :text             not null
#  metadata   :json             not null
#  read_at    :datetime
#  severity   :string           default("info"), not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_notifications_on_user_id                 (user_id)
#  index_notifications_on_user_id_and_created_at  (user_id,created_at)
#  index_notifications_on_user_id_and_dedupe_key  (user_id,dedupe_key) UNIQUE
#  index_notifications_on_user_id_and_read_at     (user_id,read_at)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class Notification < ApplicationRecord
  KINDS = %w[readiness plateau streak_risk volume_drop rest_timer].freeze
  SEVERITIES = %w[success info warning danger].freeze

  belongs_to :user

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :title, presence: true
  validates :message, presence: true
  validates :dedupe_key, presence: true, uniqueness: { scope: :user_id }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
