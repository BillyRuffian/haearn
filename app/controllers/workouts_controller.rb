# Core workout management: creating sessions, logging exercises, tracking progress
# Supports workout blocks for organizing exercises and enabling supersets
# Each workout has a start time, optional finish time, gym, and multiple workout blocks
class WorkoutsController < ApplicationController
  before_action :set_workout, only: %i[show edit update destroy finish continue_workout add_exercise reorder_blocks share_text]

  # GET /workouts
  # Lists all workouts with optional filters (gym, date range)
  def index
    @workouts = Current.user.workouts.includes(:gym, workout_exercises: [ :exercise, { machine: :photos_attachments }, { exercise_sets: [] } ]).order(started_at: :desc)

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

  # GET /workouts/:id
  # Shows workout detail with all exercises, sets, and statistics
  # This is the main workout logging interface
  def show
    # Eager load all nested associations for performance
    @workout_blocks = @workout.workout_blocks.includes(
      workout_exercises: [ :exercise, { machine: :photos_attachments }, :exercise_sets ]
    ).order(:position)
    @editing_notes = params[:editing_notes].present?

    # Fatigue Analysis for active workout
    @fatigue_data = []
    if @workout.in_progress?
      @workout.workout_exercises.includes(:exercise, :machine, :exercise_sets).each do |we|
        next if we.exercise_sets.working.empty? # Skip if no working sets yet

        analyzer = FatigueAnalyzer.new(workout_exercise: we, user: Current.user)
        analysis = analyzer.analyze
        next unless analysis # Skip if insufficient data

        @fatigue_data << {
          workout_exercise: we,
          analysis: analysis,
          message: analyzer.status_message,
          color: analyzer.status_color
        }
      end
    end
  end

  def new
    @workout = Current.user.workouts.build
    @workout.gym_id = Current.user.default_gym_id if Current.user.default_gym_id.present?
    @gyms = Current.user.gyms.ordered
  end

  # POST /workouts
  # Starts a new workout session
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

  # POST /workouts/:id/finish
  # Marks workout as complete by setting finished_at timestamp
  def finish
    @workout.finish!
    redirect_to @workout, notice: 'Workout complete! 🎉'
  end
  # Continue a recently finished workout (within 1 hour)
  # Sets finished_at back to nil, making it the active workout again
  def continue_workout
    unless @workout.can_continue?
      redirect_to @workout, alert: 'This workout was finished more than 1 hour ago and cannot be continued.'
      return
    end

    if Current.user.active_workout
      redirect_to @workout, alert: 'You already have an active workout. Finish it first.'
      return
    end

    @workout.update!(finished_at: nil)
    redirect_to @workout, notice: 'Workout continued! Keep going 💪'
  end
  # GET/POST /workouts/:id/add_exercise
  # Multi-step flow: 1) Select exercise, 2) Select machine (optional), 3) Add to workout
  # Supports adding to existing block (for supersets) via to_block param
  def add_exercise
    # GET shows exercise/machine picker, POST actually adds the exercise
    if request.post?
      add_exercise_to_workout
    else
      # Check if adding to an existing block (superset)
      @target_block = params[:to_block].present? ? @workout.workout_blocks.find(params[:to_block]) : nil

      # Step 2: If exercise selected, show machine picker
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

        # If machine_id is also present (coming back from creating a machine), auto-add the exercise
        if params[:machine_id].present?
          @selected_machine = @workout.gym.machines.find_by(id: params[:machine_id])
          if @selected_machine
            # Directly add the exercise with the selected machine
            params[:exercise_id] = @selected_exercise.id
            add_exercise_to_workout
            return
          end
        end
      else
        # Step 1: Show exercise list
        @exercises = Exercise.for_user(Current.user)
        @exercises = @exercises.where('LOWER(name) LIKE LOWER(?)', "%#{params[:search]}%") if params[:search].present?
        @exercises = @exercises.order(:name).limit(50)
      end

      render :add_exercise
    end
  end

  # POST /workouts/:id/copy
  # Creates new workout with same structure (blocks + exercises) but no sets
  # Preserves persistent notes but not session-specific notes or sets
  def copy
    # Duplicate the workout template without copying the actual logged sets
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

  # PATCH /workouts/:id/reorder_blocks
  # Updates block positions for drag-and-drop reordering
  # Expects block_ids array in desired order
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

  # GET /workouts/:id/share_text
  # Returns workout as formatted text for sharing/copying
  # NOTE: This endpoint exists but is not currently used due to iOS PWA clipboard issues
  # Text is now embedded directly in HTML for synchronous clipboard access
  def share_text
    text = generate_workout_text(@workout)
    render json: { text: text }
  end

  private

  # Helper to add exercise to workout (called from add_exercise POST)
  # Handles both new blocks and adding to existing blocks (supersets)
  # Copies persistent notes from previous workout if available
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

  # Generates shareable text summary of workout
  # Format: Date, Gym, Duration, then each exercise with sets
  # Used by clipboard controller for sharing workouts
  def generate_workout_text(workout)
    lines = []

    # Build header with date, location, and duration
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

  # Formats a single set as human-readable text
  # Handles reps, time, and distance-based exercises
  # Converts weights to user's preferred unit
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
