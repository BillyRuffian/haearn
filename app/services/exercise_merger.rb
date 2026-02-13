# Merges a duplicate exercise into a target exercise.
# All workout_exercises and template_exercises referencing the duplicate
# are reassigned to the target, then the duplicate is deleted.
#
# Usage:
#   result = ExerciseMerger.call(target: bench_press, duplicate: bench_press_2)
#   result.success?  # => true
#   result.message    # => "Merged 'Bench Press 2' into 'Bench Press'. Reassigned 5 workout uses and 2 template uses."
class ExerciseMerger
  Result = Struct.new(:success?, :message, keyword_init: true)

  def self.call(target:, duplicate:)
    new(target: target, duplicate: duplicate).call
  end

  def initialize(target:, duplicate:)
    @target = target
    @duplicate = duplicate
  end

  def call
    validate!
    merge!
  rescue ArgumentError => e
    Result.new(success?: false, message: e.message)
  end

  private

  attr_reader :target, :duplicate

  def validate!
    raise ArgumentError, 'Target and duplicate must be different exercises.' if target.id == duplicate.id
    raise ArgumentError, 'Target exercise not found.' unless target.persisted?
    raise ArgumentError, 'Duplicate exercise not found.' unless duplicate.persisted?
  end

  def merge!
    workout_count = 0
    template_count = 0

    ActiveRecord::Base.transaction do
      workout_count = duplicate.workout_exercises.update_all(exercise_id: target.id)
      template_count = TemplateExercise.where(exercise_id: duplicate.id).update_all(exercise_id: target.id)

      # Reload to clear the cached association so restrict_with_error won't block destroy
      duplicate.reload
      duplicate.destroy!
    end

    Result.new(
      success?: true,
      message: "Merged '#{duplicate.name}' into '#{target.name}'. " \
               "Reassigned #{workout_count} workout #{'use'.pluralize(workout_count)} " \
               "and #{template_count} template #{'use'.pluralize(template_count)}."
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    Result.new(success?: false, message: "Failed to delete duplicate: #{e.message}")
  end
end
