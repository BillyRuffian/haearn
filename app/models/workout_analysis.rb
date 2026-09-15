# == Schema Information
#
# Table name: workout_analyses
#
#  id                  :integer          not null, primary key
#  analysed_at         :datetime
#  error_message       :string
#  input_data          :json
#  model               :string           not null
#  processing_token    :string
#  prompt_version      :string           not null
#  request_key         :string           not null
#  response_data       :json
#  status              :string           default("pending"), not null
#  summary             :text
#  token_usage         :json
#  workout_finished_at :datetime         not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  response_id         :string
#  workout_id          :integer          not null
#
# Indexes
#
#  index_workout_analyses_on_active_workout     (workout_id) UNIQUE WHERE status IN ('pending', 'processing')
#  index_workout_analyses_on_created_at         (created_at)
#  index_workout_analyses_on_request_key        (request_key) UNIQUE
#  index_workout_analyses_on_workout_id         (workout_id)
#  index_workout_analyses_on_workout_id_and_id  (workout_id,id)
#
# Foreign Keys
#
#  workout_id  (workout_id => workouts.id)
#
class WorkoutAnalysis < ApplicationRecord
  belongs_to :workout

  enum :status, %w[pending processing completed failed].index_with(&:itself), validate: true
  validates :request_key, :model, :prompt_version, :workout_finished_at, presence: true

  scope :newest_first, -> { order(id: :desc) }
  scope :in_flight, -> { where(status: %w[pending processing]) }

  def stale?
    (pending? || processing?) && updated_at < Ai::Config.processing_lease.ago
  end

  def fail_safely!(code)
    update!(status: 'failed', error_message: code, processing_token: nil)
  end
end
