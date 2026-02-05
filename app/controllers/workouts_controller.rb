class WorkoutsController < ApplicationController
  before_action :set_workout, only: %i[show edit update destroy finish add_exercise reorder_blocks share_text]

  def index
    @workouts = Current.user.workouts.includes(:gym, workout_exercises: { exercise_sets: [] }).order(started_at: :desc)

    # Apply filters
    if params[:gym_id].present?
      @workouts = @workouts.where(gym_id: params[:gym_id])
    end

    if params[:from].present?
      @workouts = @workouts.where('started_at >= ?', Date.parse(params[:from]).beginning_of_day)
    end

    if params[:to].present?
      @workouts = @workouts.where('started_at <= ?', Date.parse(params[:to]).end_of_day)
    end

    @gyms = Current.user.gyms.ordered
    @active_workout = Current.user.active_workout
  end

  def show
    @workout_blocks = @workout.workout_blocks.includes(
      workout_exercises: [ :exercise, :machine, :exercise_sets ]
    ).order(:position)
    @editing_notes = params[:editing_notes].present?
  end

  def new
    @workout = Current.user.workouts.build
    @workout.gym_id = Current.user.default_gym_id if Current.user.default_gym_id.present?
    @gyms = Current.user.gyms.ordered
  end

  def create
    @workout = Current.user.workouts.build(workout_params)
    @workout.started_at = Time.current

    if @workout.save
      redirect_to @workout, notice: "Workout started! Let's go! 💪"
    else
      @gyms = Current.user.gyms.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @gyms = Current.user.gyms.ordered
  end

  def update
    if @workout.update(workout_params)
      redirect_to @workout, notice: 'Workout updated.'
    else
      @gyms = Current.user.gyms.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workout.destroy
    redirect_to workouts_path, notice: 'Workout deleted.'
  end

  def finish
    @workout.finish!
    redirect_to @workout, notice: 'Workout complete! 🎉'
  end

  def add_exercise
    # GET shows exercise picker, POST adds the exercise
    if request.post?
      add_exercise_to_workout
    else
      # Check if adding to an existing block (superset)
      @target_block = params[:to_block].present? ? @workout.workout_blocks.find(params[:to_block]) : nil

      # Step 2: If exercise selected, show machine picker
      if params[:select_exercise].present?
        @selected_exercise = Exercise.for_user(Current.user).find(params[:select_exercise])
        @machines = @workout.gym.machines.ordered
      else
        # Step 1: Show exercise list
        @exercises = Exercise.for_user(Current.user)
        @exercises = @exercises.where('LOWER(name) LIKE LOWER(?)', "%#{params[:search]}%") if params[:search].present?
        @exercises = @exercises.order(:name).limit(50)
      end

      render :add_exercise
    end
  end

  def copy
    # Create a new workout copying the structure of this one
    new_workout = Current.user.workouts.build(
      gym_id: @workout.gym_id,
      started_at: Time.current,
      notes: nil # Don't copy notes, those are session-specific
    )

    if new_workout.save
      # Copy blocks and exercises (but not sets - those get logged fresh)
      @workout.workout_blocks.includes(workout_exercises: [ :exercise, :machine ]).each do |block|
        new_block = new_workout.workout_blocks.create!(
          position: block.position,
          rest_seconds: block.rest_seconds
        )

        block.workout_exercises.each do |we|
          new_block.workout_exercises.create!(
            exercise_id: we.exercise_id,
            machine_id: we.machine_id,
            position: we.position,
            persistent_notes: we.persistent_notes # Keep persistent notes
          )
        end
      end

      redirect_to new_workout, notice: 'Workout copied! Ready to go! 💪'
    else
      redirect_to @workout, alert: 'Could not copy workout.'
    end
  end

  def reorder_blocks
    block_ids = params[:block_ids]

    return head :bad_request unless block_ids.is_a?(Array)

    ActiveRecord::Base.transaction do
      block_ids.each_with_index do |block_id, index|
        block = @workout.workout_blocks.find(block_id)
        block.update!(position: index + 1)
      end
    end

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def share_text
    text = generate_workout_text(@workout)
    render json: { text: text }
  end

  private

  def add_exercise_to_workout
    exercise = Exercise.for_user(Current.user).find(params[:exercise_id])
    machine = params[:machine_id].present? ? @workout.gym&.machines&.find(params[:machine_id]) : nil

    # Check if adding to an existing block (for supersets)
    if params[:to_block].present?
      block = @workout.workout_blocks.find(params[:to_block])
      position = block.workout_exercises.count + 1
    else
      # Create a new block for this exercise
      block = @workout.workout_blocks.create!(
        position: @workout.workout_blocks.count + 1,
        rest_seconds: 90
      )
      position = 1
    end

    workout_exercise = block.workout_exercises.create!(
      exercise: exercise,
      machine: machine,
      position: position
    )

    # Copy persistent notes from previous workout
    if (prev = workout_exercise.previous_workout_exercise)&.persistent_notes.present?
      workout_exercise.update(persistent_notes: prev.persistent_notes)
    end

    redirect_to @workout
  end

  def set_workout
    @workout = Current.user.workouts.find(params[:id])
  end

  def workout_params
    params.require(:workout).permit(:gym_id, :notes)
  end

  def generate_workout_text(workout)
    lines = []

    # Header
    date_str = workout.started_at.strftime('%A, %B %-d, %Y')
    lines << "🏋️ #{date_str}"
    lines << "📍 #{workout.gym.name}" if workout.gym
    lines << "⏱️ #{workout.duration_minutes} min" if workout.finished_at
    lines << ''

    # Exercises grouped by block
    workout.workout_blocks.includes(workout_exercises: [ :exercise, :machine, :exercise_sets ]).order(:position).each do |block|
      block.workout_exercises.order(:position).each do |we|
        exercise_name = we.exercise&.name || 'Unknown Exercise'
        machine_suffix = we.machine ? " (#{we.machine.name})" : ''
        lines << "#{exercise_name}#{machine_suffix}"

        we.exercise_sets.order(:position).each_with_index do |set, idx|
          set_line = format_set_text(set, idx + 1, workout.user.preferred_unit)
          lines << set_line
        end
        lines << ''
      end
    end

    # Notes
    if workout.notes.present?
      lines << "📝 Notes: #{workout.notes}"
      lines << ''
    end

    lines.join("\n").strip
  end

  def format_set_text(set, set_num, unit)
    warmup_tag = set.is_warmup ? ' (warmup)' : ''

    if set.weight_kg.present? && set.reps.present?
      weight = unit == 'lbs' ? (set.weight_kg * 2.20462).round(1) : set.weight_kg.round(1)
      "Set #{set_num}: #{set.reps} × #{weight}#{unit}#{warmup_tag}"
    elsif set.reps.present?
      "Set #{set_num}: #{set.reps} reps#{warmup_tag}"
    elsif set.duration_seconds.present?
      mins = set.duration_seconds / 60
      secs = set.duration_seconds % 60
      duration_str = mins > 0 ? "#{mins}m #{secs}s" : "#{secs}s"
      "Set #{set_num}: #{duration_str}#{warmup_tag}"
    elsif set.distance_meters.present?
      "Set #{set_num}: #{set.distance_meters}m#{warmup_tag}"
    else
      "Set #{set_num}: completed#{warmup_tag}"
    end
  end
end
