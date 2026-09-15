class AnalyseWorkoutJob < ApplicationJob
  queue_as :default

  retry_on Ai::Client::TransientError, wait: :polynomially_longer, attempts: 3 do |job, error|
    WorkoutAnalysis.update_and_broadcast(WorkoutAnalysis.where(id: job.arguments.first, status: 'pending'),
      status: 'failed', error_message: error.message, processing_token: nil, updated_at: Time.current
    )
  end

  def perform(analysis_id)
    analysis = WorkoutAnalysis.find_by(id: analysis_id)
    return unless analysis && !analysis.completed? && !analysis.failed?

    if !analysis.workout.completed? || analysis.workout.finished_at != analysis.workout_finished_at
      analysis.fail_safely!('workout_changed')
      return
    end

    token = SecureRandom.uuid
    claim = WorkoutAnalysis.where(id: analysis.id).where(status: 'pending')
      .or(WorkoutAnalysis.where(id: analysis.id, status: 'processing', updated_at: ..Ai::Config.processing_lease.ago))
    return unless WorkoutAnalysis.update_and_broadcast(claim, status: 'processing', processing_token: token, updated_at: Time.current) == 1

    analysis.reload
    result = Ai::WorkoutAnalyser.new(analysis).call
    # A continued workout or stale-worker recovery must not publish old advice.
    analysis.workout.reload
    if analysis.workout.finished_at == analysis.workout_finished_at
      WorkoutAnalysis.update_and_broadcast(owned(analysis, token), **result, status: 'completed', error_message: nil, processing_token: nil, updated_at: Time.current)
    else
      WorkoutAnalysis.update_and_broadcast(owned(analysis, token), status: 'failed', error_message: 'workout_changed', processing_token: nil, updated_at: Time.current)
    end
  rescue Ai::Client::TransientError => error
    log_failure(analysis, error)
    WorkoutAnalysis.update_and_broadcast(owned(analysis, token), status: 'pending', error_message: error.message, processing_token: nil, updated_at: Time.current)
    raise
  rescue StandardError => error
    log_failure(analysis, error)
    code = error.is_a?(Ai::Client::Error) || error.is_a?(Ai::InvalidResponse) ? error.message : error.class.name
    WorkoutAnalysis.update_and_broadcast(owned(analysis, token), status: 'failed', error_message: code, processing_token: nil, updated_at: Time.current) if analysis && token
  end

  private

  def owned(analysis, token)
    WorkoutAnalysis.where(id: analysis.id, processing_token: token, status: 'processing')
  end

  def log_failure(analysis, error)
    Rails.logger.warn("AI coaching failed analysis_id=#{analysis&.id} error_class=#{error.class.name}")
  end
end
