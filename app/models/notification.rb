# == Schema Information
#
# Table name: notifications
#
#  id                  :integer          not null, primary key
#  dedupe_key          :string           not null
#  kind                :string           not null
#  message             :text             not null
#  metadata            :json             not null
#  push_processed_at   :datetime
#  read_at             :datetime
#  severity            :string           default("info"), not null
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :integer          not null
#  workout_analysis_id :integer
#
# Indexes
#
#  index_notifications_on_kind_and_push_processed_at  (kind,push_processed_at)
#  index_notifications_on_user_id                     (user_id)
#  index_notifications_on_user_id_and_created_at      (user_id,created_at)
#  index_notifications_on_user_id_and_dedupe_key      (user_id,dedupe_key) UNIQUE
#  index_notifications_on_user_id_and_read_at         (user_id,read_at)
#  index_notifications_on_workout_analysis_id         (workout_analysis_id) UNIQUE
#
# Foreign Keys
#
#  user_id              (user_id => users.id)
#  workout_analysis_id  (workout_analysis_id => workout_analyses.id)
#
class Notification < ApplicationRecord
  KINDS = %w[rest_timer workout_analysis].freeze
  RETIRED_KINDS = %w[readiness plateau streak_risk volume_drop].freeze
  SEVERITIES = %w[success info warning danger].freeze

  belongs_to :user
  belongs_to :workout_analysis, optional: true
  validates :workout_analysis, presence: true, if: -> { kind == 'workout_analysis' }

  after_create_commit :enqueue_analysis_push, if: -> { kind == 'workout_analysis' && push_processed_at.nil? }

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :title, presence: true
  validates :message, presence: true
  validates :dedupe_key, presence: true, uniqueness: { scope: :user_id }

  scope :active, -> { where(kind: KINDS) }
  scope :center, -> { active.where.not(kind: 'rest_timer') }
  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def action_path
    if kind == 'workout_analysis'
      Rails.application.routes.url_helpers.workout_path(metadata['workout_id'], analysis_id: workout_analysis_id, anchor: 'ai-coaching')
    elsif metadata['workout_id'].present?
      Rails.application.routes.url_helpers.workout_path(metadata['workout_id'])
    else
      '/'
    end
  end

  private

  def enqueue_analysis_push
    DeliverAnalysisNotificationJob.perform_later(id)
  rescue StandardError => error
    Rails.logger.warn("AI notification enqueue failed notification_id=#{id} error_class=#{error.class.name}")
  end
end
