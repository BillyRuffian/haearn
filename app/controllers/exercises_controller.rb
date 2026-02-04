class ExercisesController < ApplicationController
  before_action :set_exercise, only: %i[show edit update destroy history]

  def index
    @exercises = Exercise.for_user(Current.user).ordered

    # Filter by type
    if params[:type].present? && Exercise::EXERCISE_TYPES.include?(params[:type])
      @exercises = @exercises.where(exercise_type: params[:type])
    end

    # Filter by weighted
    if params[:weighted] == 'true'
      @exercises = @exercises.where(has_weight: true)
    elsif params[:weighted] == 'false'
      @exercises = @exercises.where(has_weight: false)
    end

    # Filter by source (global vs user)
    if params[:source] == 'global'
      @exercises = @exercises.global
    elsif params[:source] == 'mine'
      @exercises = @exercises.where(user_id: Current.user.id)
    end

    # Search by name
    if params[:q].present?
      @exercises = @exercises.where('name LIKE ?', "%#{params[:q]}%")
    end

    # For new exercise form
    @exercise = Current.user.exercises.build

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    redirect_to exercises_path
  end

  def new
    @exercise = Current.user.exercises.build
    @return_to = params[:return_to]
  end

  def create
    @exercise = Current.user.exercises.build(exercise_params)

    respond_to do |format|
      if @exercise.save
        # If we have a return_to URL, redirect there instead
        if params[:return_to].present?
          safe_url = safe_return_to(params[:return_to], fallback: exercises_path)
          format.html { redirect_to safe_url, notice: 'Exercise created! Now select it.' }
          format.turbo_stream { redirect_to safe_url, notice: 'Exercise created! Now select it.' }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('exercises', partial: 'exercises/exercise', locals: { exercise: @exercise }),
              turbo_stream.update('new_exercise_form', partial: 'exercises/form', locals: { exercise: Current.user.exercises.build })
            ]
          end
          format.html { redirect_to exercises_path, notice: 'Exercise created successfully.' }
        end
      else
        @return_to = params[:return_to]
        format.turbo_stream { render turbo_stream: turbo_stream.update('new_exercise_form', partial: 'exercises/form', locals: { exercise: @exercise }) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    # Only allow editing user's own exercises
    unless @exercise.user_id == Current.user.id
      redirect_to exercises_path, alert: 'You can only edit your own exercises.'
    end
  end

  def update
    # Only allow updating user's own exercises
    unless @exercise.user_id == Current.user.id
      return redirect_to exercises_path, alert: 'You can only edit your own exercises.'
    end

    respond_to do |format|
      if @exercise.update(exercise_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@exercise, partial: 'exercises/exercise', locals: { exercise: @exercise }) }
        format.html { redirect_to exercises_path, notice: 'Exercise updated successfully.' }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@exercise, partial: 'exercises/edit_form', locals: { exercise: @exercise }) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    # Only allow deleting user's own exercises
    unless @exercise.user_id == Current.user.id
      return redirect_to exercises_path, alert: 'You can only delete your own exercises.'
    end

    # Check if exercise has been used in workouts
    usage_count = @exercise.workout_exercises.count

    if usage_count > 0 && params[:force] != 'true'
      # Redirect back with info about usage - the view will show a confirmation modal
      redirect_to exercises_path, alert: "This exercise has been used #{usage_count} #{'time'.pluralize(usage_count)} in your workouts. Use the delete button again to confirm deletion of all associated data."
    else
      # Delete associated workout_exercises first (this cascades to sets)
      @exercise.workout_exercises.destroy_all if usage_count > 0
      @exercise.destroy

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove(@exercise) }
        format.html { redirect_to exercises_path, notice: 'Exercise deleted.' }
      end
    end
  end

  def history
    # Get all workout exercises for this exercise from the current user's workouts
    @workout_exercises = WorkoutExercise
      .joins(:workout_block)
      .joins('INNER JOIN workouts ON workouts.id = workout_blocks.workout_id')
      .where(workouts: { user_id: Current.user.id })
      .where(exercise_id: @exercise.id)
      .includes(:machine, :exercise_sets, workout_block: :workout)
      .order('workouts.started_at DESC')

    # Calculate PRs for this exercise
    @prs = calculate_prs(@workout_exercises)

    # Group by machine if applicable
    @by_machine = @workout_exercises.group_by(&:machine)

    # Build chart data for progress visualization
    @chart_data = build_chart_data(@workout_exercises)
  end

  private

  def calculate_prs(workout_exercises)
    prs = {
      best_set_weight: nil,      # Heaviest single set weight
      best_set_volume: nil,      # Highest volume single set (weight * reps)
      best_session_volume: nil,  # Highest total volume in a session
      best_e1rm: nil,            # Highest estimated 1RM
      best_reps_at_weight: {}    # Best reps for each weight
    }

    all_sets = workout_exercises.flat_map(&:exercise_sets).select { |s| !s.is_warmup }

    return prs if all_sets.empty?

    # Best set weight
    if @exercise.has_weight?
      best_weight_set = all_sets.max_by(&:weight_kg)
      if best_weight_set
        prs[:best_set_weight] = {
          weight_kg: best_weight_set.weight_kg,
          reps: best_weight_set.reps,
          date: best_weight_set.completed_at&.to_date || best_weight_set.created_at.to_date
        }
      end

      # Best set volume (single set)
      best_volume_set = all_sets.max_by { |s| (s.weight_kg || 0) * (s.reps || 0) }
      if best_volume_set
        prs[:best_set_volume] = {
          weight_kg: best_volume_set.weight_kg,
          reps: best_volume_set.reps,
          volume: (best_volume_set.weight_kg || 0) * (best_volume_set.reps || 0),
          date: best_volume_set.completed_at&.to_date || best_volume_set.created_at.to_date
        }
      end

      # Best estimated 1RM (Epley formula)
      best_e1rm_value = 0
      best_e1rm_set = nil
      all_sets.each do |s|
        next unless s.weight_kg && s.reps && s.reps > 0
        e1rm = s.weight_kg * (1 + s.reps.to_f / 30)
        if e1rm > best_e1rm_value
          best_e1rm_value = e1rm
          best_e1rm_set = s
        end
      end
      if best_e1rm_set
        prs[:best_e1rm] = {
          e1rm_kg: best_e1rm_value,
          weight_kg: best_e1rm_set.weight_kg,
          reps: best_e1rm_set.reps,
          date: best_e1rm_set.completed_at&.to_date || best_e1rm_set.created_at.to_date
        }
      end

      # Best session volume
      session_volumes = workout_exercises.map do |we|
        work_sets = we.exercise_sets.reject(&:is_warmup)
        volume = work_sets.sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
        { workout_exercise: we, volume: volume }
      end
      best_session = session_volumes.max_by { |sv| sv[:volume] }
      if best_session && best_session[:volume] > 0
        prs[:best_session_volume] = {
          volume: best_session[:volume],
          workout: best_session[:workout_exercise].workout_block.workout,
          date: best_session[:workout_exercise].workout_block.workout.started_at.to_date
        }
      end
    end

    prs
  end

  def build_chart_data(workout_exercises)
    return {} if workout_exercises.empty?

    # Convert to array to preserve loaded associations
    exercises_array = workout_exercises.to_a

    # Sort by date ascending for charts
    sorted = exercises_array.sort_by { |we| we.workout_block.workout.started_at }

    # Prepare data points
    weight_data = []
    volume_data = []
    e1rm_data = []
    labels = []

    sorted.each do |we|
      workout = we.workout_block.workout
      # Use date + time if multiple sessions on same day
      date_label = workout.started_at.strftime('%b %d %H:%M')
      date_iso = workout.started_at.to_date.to_s
      work_sets = we.exercise_sets.select { |s| !s.is_warmup }

      next if work_sets.empty?

      labels << date_label

      if @exercise.has_weight?
        # Max weight in this session
        max_weight = work_sets.map(&:weight_kg).compact.max || 0
        weight_data << Current.user.display_weight(max_weight).round(1)

        # Session volume
        session_volume = work_sets.sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
        volume_data << Current.user.display_weight(session_volume).round

        # Estimated 1RM (best from session using Epley formula)
        best_e1rm = 0
        best_set = nil
        work_sets.each do |s|
          next unless s.weight_kg && s.reps && s.reps > 0
          # Epley formula: 1RM = weight × (1 + reps/30)
          e1rm = s.weight_kg * (1 + s.reps.to_f / 30)
          if e1rm > best_e1rm
            best_e1rm = e1rm
            best_set = s
          end
        end

        if best_set
          e1rm_data << {
            date: date_iso,
            e1rm: Current.user.display_weight(best_e1rm).round(1),
            weight: Current.user.display_weight(best_set.weight_kg).round(1),
            reps: best_set.reps
          }
        end
      end
    end

    {
      labels: labels,
      weight: {
        labels: labels,
        datasets: [ {
          label: "Max Weight (#{Current.user.preferred_unit})",
          data: weight_data,
          borderColor: '#c86432',
          backgroundColor: 'rgba(200, 100, 50, 0.2)',
          fill: true
        } ]
      },
      volume: {
        labels: labels,
        datasets: [ {
          label: "Session Volume (#{Current.user.preferred_unit})",
          data: volume_data,
          borderColor: '#f0a060',
          backgroundColor: 'rgba(240, 160, 96, 0.2)',
          fill: true
        } ]
      },
      e1rm: e1rm_data
    }
  end

  def set_exercise
    @exercise = Exercise.for_user(Current.user).find(params[:id])
  end

  def exercise_params
    params.require(:exercise).permit(:name, :exercise_type, :has_weight, :description)
  end
end
