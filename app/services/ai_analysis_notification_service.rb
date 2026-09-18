class AiAnalysisNotificationService
  def self.record!(analysis)
    return unless analysis.completed? && analysis.workout.completed?
    return unless analysis.workout.finished_at == analysis.workout_finished_at

    user = analysis.workout.user
    user.notifications.find_or_create_by!(dedupe_key: "workout-analysis:#{analysis.id}") do |notification|
      notification.assign_attributes(
        workout_analysis: analysis, kind: 'workout_analysis', severity: 'info',
        title: 'Your AI workout review is ready',
        message: 'Open your workout to read the review and next-session recommendations.',
        metadata: { workout_id: analysis.workout_id, analysis_id: analysis.id },
        push_processed_at: AppPresence.visible_for?(user) ? Time.current : nil
      )
    end
  end
end
