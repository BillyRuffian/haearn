module Ai
  class RequestWorkoutAnalysis
    def self.call(workout, automatic: false)
      analysis = nil
      created = false
      workout.with_lock do
        raise ArgumentError, 'Only completed workouts can be analysed' unless workout.completed?

        inflight = workout.workout_analyses.in_flight.first
        if inflight && (inflight.stale? || inflight.workout_finished_at != workout.finished_at)
          inflight.fail_safely!('superseded_or_interrupted')
          inflight = nil
        end
        key = automatic ? "completion:#{workout.id}:#{workout.finished_at.iso8601(6)}" : SecureRandom.uuid
        analysis = inflight || workout.workout_analyses.find_by(request_key: key)
        unless analysis
          analysis = workout.workout_analyses.create!(
            request_key: key, workout_finished_at: workout.finished_at,
            model: Config.model, prompt_version: Config.prompt_version
          )
          created = true
        end
      end
      if created
        begin
          job = AnalyseWorkoutJob.perform_later(analysis.id)
          analysis.fail_safely!('enqueue_failed') unless job
        rescue StandardError => error
          Rails.logger.error("AI coaching enqueue failed analysis_id=#{analysis.id} error_class=#{error.class.name}")
          analysis.fail_safely!('enqueue_failed')
        end
      end
      analysis
    end
  end
end
