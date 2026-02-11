# Manages individual exercise entries within a workout
# Handles two types of notes: session_notes (temporary) and persistent_notes (carried forward)
# Supports moving exercises between blocks for creating/breaking supersets
class WorkoutExercisesController < ApplicationController
  before_action :set_workout
  before_action :set_workout_exercise

  # GET /workouts/:workout_id/workout_exercises/:id
  # Returns to display mode after editing notes (Turbo Stream)
  def show
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "workout_exercise_notes_#{@workout_exercise.id}",
          partial: 'workout_exercises/notes_display',
          locals: { workout: @workout, workout_exercise: @workout_exercise }
        )
      end
      format.html { redirect_to @workout }
    end
  end

  # GET /workouts/:workout_id/workout_exercises/:id/edit
  # Switches to inline edit form for notes (Turbo Stream)
  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "workout_exercise_notes_#{@workout_exercise.id}",
          partial: 'workout_exercises/notes_form',
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
            partial: 'workout_exercises/notes_display',
            locals: { workout: @workout, workout_exercise: @workout_exercise }
          )
        end
        format.html { redirect_to @workout, notice: 'Notes updated.' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "workout_exercise_notes_#{@workout_exercise.id}",
            partial: 'workout_exercises/notes_form',
            locals: { workout: @workout, workout_exercise: @workout_exercise }
          )
        end
        format.html { redirect_to @workout, alert: 'Could not update notes.' }
      end
    end
  end

  # DELETE /workouts/:workout_id/workout_exercises/:id
  # Removes exercise from workout and cleans up empty blocks
  def destroy
    block = @workout_exercise.workout_block

    @workout_exercise.destroy

    # Auto-cleanup: delete the containing block if it becomes empty
    if block.workout_exercises.empty?
      block.destroy
    end

    redirect_to @workout, notice: 'Exercise removed.'
  end

  # POST /workouts/:workout_id/workout_exercises/:id/move_to_block
  # Moves exercise to different block (for creating/breaking supersets)
  # Supports creating new block via target_block_id='new'
  def move_to_block
    target_block_id = params[:target_block_id]

    if target_block_id == 'new'
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

    redirect_to @workout, notice: 'Exercise moved.'
  end

  # GET/POST /workouts/:workout_id/workout_exercises/:id/swap_exercise
  # Multi-step flow: 1) Select exercise, 2) Select machine, 3) Swap in-place
  # Preserves block position, sets, and session_notes; refreshes persistent_notes
  def swap_exercise
    if request.post?
      perform_swap
    else
      if params[:select_exercise].present?
        @selected_exercise = Exercise.for_user(Current.user).find(params[:select_exercise])
        @machines = @workout.gym.machines.with_attached_photos.ordered

        @recent_machines = @workout.gym.machines
          .joins(workout_exercises: { workout_block: :workout })
          .where(workout_exercises: { exercise_id: @selected_exercise.id })
          .where(workouts: { user_id: Current.user.id, finished_at: ..Time.current })
          .select('machines.*, MAX(workouts.started_at) AS last_used_at')
          .group('machines.id')
          .order('last_used_at DESC')
          .limit(3)
          .with_attached_photos
      else
        @exercises = Exercise.for_user(Current.user)
        @exercises = @exercises.where('LOWER(name) LIKE LOWER(?)', "%#{params[:search]}%") if params[:search].present?
        @exercises = @exercises.order(:name).limit(50)
      end

      render :swap_exercise
    end
  end

  # POST /workouts/:workout_id/workout_exercises/:id/generate_warmups
  # Auto-generates warmup sets based on target working weight
  def generate_warmups
    working_weight_kg = params[:working_weight_kg].to_f

    # Convert from user's unit/machine display unit to kg if needed
    if @workout_exercise.machine.present?
      working_weight_kg = WeightConverter.machine_to_kg(
        params[:working_weight].to_f,
        @workout_exercise.machine
      )
    elsif params[:working_weight].present?
      working_weight_kg = WeightConverter.to_kg(
        params[:working_weight].to_f,
        Current.user.preferred_unit
      )
    end

    # Generate and create warmup sets
    created_sets = WarmupGenerator.create_for(
      workout_exercise: @workout_exercise,
      working_weight_kg: working_weight_kg
    )

    respond_to do |format|
      if created_sets.any?
        @workout.reload
        format.turbo_stream do
          render turbo_stream: [
            # Append each warmup set
            *created_sets.map.with_index do |set, idx|
              turbo_stream.append(
                "sets_list_#{@workout_exercise.id}",
                partial: 'exercise_sets/exercise_set',
                locals: {
                  set: set,
                  workout_exercise: @workout_exercise,
                  workout: @workout,
                  index: idx + 1
                }
              )
            end,
            # Update workout stats
            turbo_stream.replace(
              'workout_stats',
              partial: 'workouts/stats',
              locals: { workout: @workout }
            ),
            # Hide the warmup generator form
            turbo_stream.update(
              "warmup_generator_#{@workout_exercise.id}",
              html: ''
            )
          ]
        end
        format.html { redirect_to @workout, notice: "#{created_sets.count} warmup sets added." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "warmup_generator_#{@workout_exercise.id}",
            html: "<div class='alert alert-warning small'>Could not generate warmups. Working weight may be too light.</div>"
          )
        end
        format.html { redirect_to @workout, alert: 'Could not generate warmups.' }
      end
    end
  end

  private

  def set_workout
    @workout = Current.user.workouts.find(params[:workout_id])
  end

  def set_workout_exercise
    @workout_exercise = @workout.workout_exercises.find(params[:id])
  end

  # Swaps exercise and/or machine on existing workout_exercise
  # Preserves block position, sets, and session_notes
  # Refreshes persistent_notes from new exercise+machine history
  def perform_swap
    exercise = Exercise.for_user(Current.user).find(params[:exercise_id])
    machine = @workout.gym.machines.find(params[:machine_id])

    @workout_exercise.update!(
      exercise: exercise,
      machine: machine
    )

    # Refresh persistent_notes from previous workout with new exercise+machine combo
    prev = @workout_exercise.previous_workout_exercise
    @workout_exercise.update!(persistent_notes: prev&.persistent_notes)

    redirect_to @workout, notice: 'Exercise swapped.'
  end

  # Strong params for both types of notes
  # session_notes: specific to this workout ("elbow hurt on set 3")
  # persistent_notes: carried to future workouts ("use neutral grip handle")
  def workout_exercise_params
    params.require(:workout_exercise).permit(:session_notes, :persistent_notes)
  end
end
