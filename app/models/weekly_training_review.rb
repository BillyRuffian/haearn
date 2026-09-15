# == Schema Information
#
# Table name: weekly_training_reviews
#
#  id                  :integer          not null, primary key
#  analysed_at         :datetime
#  attempts            :integer          default(0), not null
#  delivery_error      :string
#  delivery_started_at :datetime
#  delivery_status     :string           default("pending"), not null
#  error_message       :string
#  input_data          :json
#  model               :string           not null
#  processing_token    :string
#  prompt_version      :string           not null
#  response_data       :json
#  retry_at            :datetime
#  sent_at             :datetime
#  status              :string           default("pending"), not null
#  summary_data        :json
#  token_usage         :json
#  week_start          :date             not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  response_id         :string
#  user_id             :integer          not null
#
# Indexes
#
#  index_weekly_reviews_on_recovery                         (delivery_status,status,retry_at)
#  index_weekly_training_reviews_on_user_id                 (user_id)
#  index_weekly_training_reviews_on_user_id_and_week_start  (user_id,week_start) UNIQUE
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class WeeklyTrainingReview < ApplicationRecord
  belongs_to :user
  enum :status, %w[pending processing completed failed].index_with(&:itself), validate: true
  enum :delivery_status, %w[pending sending sent uncertain skipped].index_with(&:itself), prefix: :delivery, validate: true
  validates :week_start, :model, :prompt_version, presence: true
  validate :completed_calendar_week

  scope :recoverable, -> {
    where(delivery_status: 'pending').where(retry_at: nil).or(where(delivery_status: 'pending', retry_at: ..Time.current))
  }

  def ready_to_send?
    (completed? || failed?) && summary_data.present?
  end

  def self.request!(user:, week_start:)
    start = week_start.to_date.beginning_of_week
    create_or_find_by!(user: user, week_start: start) do |review|
      review.model = Ai::Config.weekly_model
      review.prompt_version = Ai::Config.weekly_prompt_version
    end
  end

  private

  def completed_calendar_week
    return unless week_start

    errors.add(:week_start, 'must be a completed Monday–Sunday week') unless week_start.monday? && week_start < Date.current.beginning_of_week
  end
end
