class WorkoutExercisesController < ApplicationController
  before_action :set_workout
  before_action :set_workout_exercise

  def show
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "workout_exercise_notes_#{@workout_exercise.id}",
          partial: "workout_exercises/notes_display",
          locals: { workout: @workout, workout_exercise: @workout_exercise }
        )
      end
      format.html { redirect_to @workout }
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "workout_exercise_notes_#{@workout_exercise.id}",
          partial: "workout_exercises/notes_form",
          locals: { workout: @workout, workout_exercise: @workout_exercise }
        )
      end
      format.html { redirect_to @workout }
    end
  end

  def update
    if @workout_exercise.update(workout_exercise_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "workout_exercise_notes_#{@workout_exercise.id}",
            partial: "workout_exercises/notes_display",
            locals: { workout: @workout, workout_exercise: @workout_exercise }
          )
        end
        format.html { redirect_to @workout, notice: "Notes updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "workout_exercise_notes_#{@workout_exercise.id}",
            partial: "workout_exercises/notes_form",
            locals: { workout: @workout, workout_exercise: @workout_exercise }
          )
        end
        format.html { redirect_to @workout, alert: "Could not update notes." }
      end
    end
  end

  def destroy
    block = @workout_exercise.workout_block

    @workout_exercise.destroy

    # If this was the only exercise in the block, delete the block too
    if block.workout_exercises.empty?
      block.destroy
    end

    redirect_to @workout, notice: "Exercise removed."
  end

  def move_to_block
    target_block_id = params[:target_block_id]

    if target_block_id == "new"
      # Create a new block
      target_block = @workout.workout_blocks.create!(
        position: @workout.workout_blocks.maximum(:position).to_i + 1,
        rest_seconds: 90
      )
    else
      target_block = @workout.workout_blocks.find(target_block_id)
    end

    old_block = @workout_exercise.workout_block

    # Move the exercise
    @workout_exercise.update!(
      workout_block: target_block,
      position: target_block.workout_exercises.count + 1
    )

    # Delete old block if empty
    old_block.destroy if old_block.workout_exercises.empty?

    redirect_to @workout, notice: "Exercise moved."
  end

  private

  def set_workout
    @workout = Current.user.workouts.find(params[:workout_id])
  end

  def set_workout_exercise
    @workout_exercise = @workout.workout_exercises.find(params[:id])
  end

  def workout_exercise_params
    params.require(:workout_exercise).permit(:session_notes, :persistent_notes)
  end
end
