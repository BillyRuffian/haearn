# Manages the exercise library (both global/seeded exercises and user-created ones)
# Supports filtering by type, weighted/bodyweight, source, and search
class ExercisesController < ApplicationController
  before_action :set_exercise, only: %i[show edit update destroy history]

  # GET /exercises
  # Lists all exercises with optional filtering
  # Supports filters: type (reps/time/distance), weighted, source (global/mine), and search query
  def index
    # Shows both global (seeded) exercises and user's custom exercises
    @exercises = Exercise.for_user(Current.user).ordered

    # Apply filters based on params
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

  # POST /exercises
  # Creates new custom exercise for the user
  # Supports return_to param for redirecting back to workout setup flow
  def create
    @exercise = Current.user.exercises.build(exercise_params)

    respond_to do |format|
      if @exercise.save
        # Support for workout flow: create exercise, then return to exercise picker
        if params[:return_to].present?
          # Append select_exercise param to auto-select the newly created exercise
          safe_url = safe_return_to_with_param(params[:return_to], :select_exercise, @exercise.id, fallback: exercises_path)
          format.html { redirect_to safe_url, notice: 'Exercise created!' }
          format.turbo_stream { redirect_to safe_url, notice: 'Exercise created!' }
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

  # GET /exercises/:id/edit
  # Inline edit form via Turbo Frame
  def edit
    # Users can only edit their own custom exercises, not global ones
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

  # DELETE /exercises/:id
  # Deletes exercise with safety check for usage in workouts
  # Requires force=true confirmation if exercise has been used
  def destroy
    # Users can only delete their own custom exercises, not global ones
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

  # GET /exercises/:id/history
  # Shows complete workout history for this exercise with PRs and progress charts
  # Displays PRs overall and per-machine, with detailed graphs
  def history
    # Load all instances of this exercise across all user's workouts
    @workout_exercises = WorkoutExercise
      .joins(:workout_block)
      .joins('INNER JOIN workouts ON workouts.id = workout_blocks.workout_id')
      .where(workouts: { user_id: Current.user.id })
      .where(exercise_id: @exercise.id)
      .includes(:machine, :exercise_sets, workout_block: :workout)
      .order('workouts.started_at DESC')

    # Calculate overall PRs for the exercise (max weight, max volume, best E1RM)
    @prs = PrCalculator.calculate_all(@workout_exercises, exercise: @exercise)

    # Group by machine if applicable
    @by_machine = @workout_exercises.group_by(&:machine)

    # Calculate PRs per machine for accurate PR badges in each tab
    @prs_by_machine = {}
    @by_machine.each do |machine, wes|
      @prs_by_machine[machine] = PrCalculator.calculate_all(wes, exercise: @exercise)
    end

    # Build chart data for progress visualization
    @chart_data = build_chart_data(@workout_exercises)
  end

  private

  # Builds chart data for progress graphs: weight progression, volume trends, and estimated 1RM
  # Returns data formatted for Chart.js consumption
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
    params.require(:exercise).permit(:name, :exercise_type, :has_weight, :description, :primary_muscle_group)
  end
end
