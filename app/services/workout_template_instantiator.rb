class WorkoutTemplateInstantiator
  def initialize(user:, workout_template:, gym:, program_session_execution: nil, workout: nil)
    @user = user
    @workout_template = workout_template
    @gym = gym
    @program_session_execution = program_session_execution
    @workout = workout
  end

  def call
    Workout.transaction do
      workout = @workout || create_workout!
      ensure_appendable!(workout)
      append_template_to!(workout)
      workout
    end
  end

  private

  def create_workout!
    @user.workouts.create!(
      gym: @gym,
      started_at: Time.current,
      program_session_execution: @program_session_execution
    )
  end

  def ensure_appendable!(workout)
    return if workout.user_id == @user.id && workout.in_progress?

    raise ArgumentError, 'template destination must be the user active workout'
  end

  def append_template_to!(workout)
    next_position = workout.workout_blocks.maximum(:position).to_i

    @workout_template.template_blocks.ordered.each do |template_block|
      next_position += 1
      workout_block = workout.workout_blocks.create!(
        position: next_position,
        rest_seconds: template_block.rest_seconds
      )

      template_block.template_exercises.order(:id).each do |template_exercise|
        workout_block.workout_exercises.create!(
          exercise: template_exercise.exercise,
          machine: template_exercise.machine,
          template_exercise: template_exercise,
          persistent_notes: template_exercise.persistent_notes
        )
      end
    end
  end
end
