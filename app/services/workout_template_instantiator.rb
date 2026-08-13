class WorkoutTemplateInstantiator
  def initialize(user:, workout_template:, gym:, program_session_execution: nil)
    @user = user
    @workout_template = workout_template
    @gym = gym
    @program_session_execution = program_session_execution
  end

  def call
    Workout.transaction do
      workout = @user.workouts.build(
        gym: @gym,
        started_at: Time.current,
        program_session_execution: @program_session_execution
      )

      @workout_template.template_blocks.ordered.each do |template_block|
        workout_block = workout.workout_blocks.build(
          position: template_block.position,
          rest_seconds: template_block.rest_seconds
        )

        template_block.template_exercises.order(:id).each do |template_exercise|
          workout_block.workout_exercises.build(
            exercise: template_exercise.exercise,
            machine: template_exercise.machine,
            template_exercise: template_exercise,
            persistent_notes: template_exercise.persistent_notes
          )
        end
      end

      workout.save!
      workout
    end
  end
end
