# Handles CRUD operations for individual exercise sets within workout exercises
# Uses Turbo Streams for smooth, inline editing without full page reloads
class ExerciseSetsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_workout_and_exercise
  before_action :set_exercise_set, only: %i[edit update destroy duplicate]

  # POST /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets
  # Creates a new set and updates the workout stats via Turbo Stream
  def create
    # Build new set with auto-incremented position
    @exercise_set = @workout_exercise.exercise_sets.build(exercise_set_params)
    @exercise_set.position = @workout_exercise.exercise_sets.count + 1
    @exercise_set.completed_at = Time.current

    respond_to do |format|
      if @exercise_set.save
        @workout.reload # Reload to get updated counts for stats display
        index = @workout_exercise.exercise_sets.count
        # Return multiple Turbo Streams: append new set, reset form, update stats
        format.turbo_stream do
          streams = [
            turbo_stream.append("sets_list_#{@workout_exercise.id}",
              partial: 'exercise_sets/exercise_set',
              locals: { set: @exercise_set, workout_exercise: @workout_exercise, workout: @workout, index: index }),
            turbo_stream.replace("new_set_#{@workout_exercise.id}",
              partial: 'exercise_sets/form',
              locals: {
                workout_exercise: @workout_exercise,
                workout: @workout,
                set: @workout_exercise.exercise_sets.build,
                quick_log_mode: params[:quick_log] == '1'
              }),
            turbo_stream.replace('workout_stats',
              partial: 'workouts/stats',
              locals: { workout: @workout })
          ]

          # Hide warmup generator after first set is logged
          if @workout_exercise.exercise_sets.count == 1
            streams << turbo_stream.remove("warmup_generator_#{@workout_exercise.id}")
          end

          append_volume_pr_stream(streams)
          render turbo_stream: streams
        end
        format.html { redirect_to workout_path(@workout) }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("new_set_#{@workout_exercise.id}",
            partial: 'exercise_sets/form',
            locals: {
              workout_exercise: @workout_exercise,
              workout: @workout,
              set: @exercise_set,
              quick_log_mode: params[:quick_log] == '1'
            })
        end
        format.html { redirect_to workout_path(@workout), alert: 'Could not save set.' }
      end
    end
  end

  # GET /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id/edit
  # Replaces set display with inline edit form via Turbo Frame
  def edit
    # Calculate the set number for display (1-indexed)
    index = @workout_exercise.exercise_sets.order(:created_at).pluck(:id).index(@exercise_set.id) + 1
    render partial: 'exercise_sets/edit_form',
           locals: { set: @exercise_set, workout_exercise: @workout_exercise, workout: @workout, index: index }
  end

  # PATCH /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id
  # Updates set and refreshes both the set display and workout stats
  def update
    respond_to do |format|
      if @exercise_set.update(exercise_set_params)
        @workout.reload # Reload to get updated volume for stats
        # Calculate set number again after update
        index = @workout_exercise.exercise_sets.order(:created_at).pluck(:id).index(@exercise_set.id) + 1
        format.turbo_stream do
          streams = [
            turbo_stream.replace(@exercise_set,
              partial: 'exercise_sets/exercise_set',
              locals: { set: @exercise_set, workout_exercise: @workout_exercise, workout: @workout, index: index }),
            turbo_stream.replace('workout_stats',
              partial: 'workouts/stats',
              locals: { workout: @workout })
          ]

          append_volume_pr_stream(streams)
          render turbo_stream: streams
        end
        format.html { redirect_to workout_path(@workout) }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(@exercise_set,
            partial: 'exercise_sets/edit_form',
            locals: { set: @exercise_set, workout_exercise: @workout_exercise, workout: @workout })
        end
        format.html { redirect_to workout_path(@workout), alert: 'Could not update set.' }
      end
    end
  end

  # DELETE /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id
  # Removes set and updates workout stats
  def destroy
    @exercise_set.destroy
    @workout.reload # Reload to get updated counts for stats

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.remove(@exercise_set),
          turbo_stream.replace('workout_stats',
            partial: 'workouts/stats',
            locals: { workout: @workout })
        ]

        append_volume_pr_stream(streams)
        render turbo_stream: streams
      end
      format.html { redirect_to workout_path(@workout) }
    end
  end

  # POST /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id/duplicate
  # Copies the set with a new position and timestamp
  def duplicate
    new_set = @exercise_set.dup
    new_set.position = @workout_exercise.exercise_sets.count + 1
    new_set.completed_at = Time.current

    if new_set.save
      @workout.reload
      index = @workout_exercise.exercise_sets.count

      respond_to do |format|
        format.turbo_stream do
          streams = [
            turbo_stream.append("sets_list_#{@workout_exercise.id}",
              partial: 'exercise_sets/exercise_set',
              locals: { set: new_set, workout_exercise: @workout_exercise, workout: @workout, index: index }),
            turbo_stream.replace('workout_stats',
              partial: 'workouts/stats',
              locals: { workout: @workout })
          ]

          append_volume_pr_stream(streams)
          render turbo_stream: streams
        end
        format.html { redirect_to workout_path(@workout) }
      end
    else
      redirect_to workout_path(@workout), alert: 'Could not duplicate set.'
    end
  end

  private

  # Load workout and workout_exercise from nested route params
  def set_workout_and_exercise
    @workout = Current.user.workouts.find(params[:workout_id])
    @workout_exercise = @workout.workout_exercises.find(params[:workout_exercise_id])
  end

  def set_exercise_set
    @exercise_set = @workout_exercise.exercise_sets.find(params[:id])
  end

  # Re-render the workout exercise card to reflect current volume PR status
  def append_volume_pr_stream(streams)
    @workout_exercise.reload
    streams << turbo_stream.replace(dom_id(@workout_exercise),
      partial: 'workouts/workout_exercise',
      locals: { workout_exercise: @workout_exercise, workout: @workout, superset_label: superset_label_for(@workout_exercise) })
  end

  # Compute superset label (e.g. "A1", "A2") for re-rendering the workout_exercise partial
  def superset_label_for(workout_exercise)
    block = workout_exercise.workout_block
    return nil unless block.workout_exercises.count > 1

    index = block.workout_exercises.order(:position).pluck(:id).index(workout_exercise.id)
    "#{(block.position + 64).chr}#{index + 1}"
  end

  # Strong params with weight conversion logic
  # Converts user's input weight (in their preferred unit) to kg for database storage
  # Handles machine-specific weight ratios (e.g., 2:1 pulley systems)
  def exercise_set_params
    permitted = params.require(:exercise_set).permit(
      :weight_kg, :weight_value, :reps, :duration_seconds, :distance_meters,
      :is_warmup, :rpe, :rir,
      :is_amrap, :set_type,
      :tempo_eccentric, :tempo_pause_bottom, :tempo_concentric, :tempo_pause_top,
      :belt, :knee_sleeves, :wrist_wraps, :straps,
      :is_failed, :spotter_assisted, :pain_flag, :is_bfr,
      :partial_reps, :pain_note, :band_tension_kg, :chain_weight_kg
    )

    # Convert weight from user's input unit to kg for normalized storage
    if permitted[:weight_value].present?
      # If a machine is selected, use machine's display unit and weight ratio
      if @workout_exercise.machine.present?
        permitted[:weight_kg] = WeightConverter.machine_to_kg(
          permitted[:weight_value].to_f,
          @workout_exercise.machine
        )
      else
        # Otherwise use user's preferred unit
        permitted[:weight_kg] = WeightConverter.to_kg(
          permitted[:weight_value].to_f,
          Current.user.preferred_unit
        )
      end
      permitted.delete(:weight_value)
    end

    permitted
  end
end
