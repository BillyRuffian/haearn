class WorkoutsController < ApplicationController
  before_action :set_workout, only: %i[show edit update destroy finish add_exercise]

  def index
    @workouts = Current.user.workouts.includes(:gym, workout_exercises: { exercise_sets: [] }).order(started_at: :desc)

    # Apply filters
    if params[:gym_id].present?
      @workouts = @workouts.where(gym_id: params[:gym_id])
    end

    if params[:from].present?
      @workouts = @workouts.where("started_at >= ?", Date.parse(params[:from]).beginning_of_day)
    end

    if params[:to].present?
      @workouts = @workouts.where("started_at <= ?", Date.parse(params[:to]).end_of_day)
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
      redirect_to @workout, notice: "Workout updated."
    else
      @gyms = Current.user.gyms.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workout.destroy
    redirect_to workouts_path, notice: "Workout deleted."
  end

  def finish
    @workout.finish!
    redirect_to @workout, notice: "Workout complete! 🎉"
  end

  def add_exercise
    # GET shows exercise picker, POST adds the exercise
    if request.post?
      add_exercise_to_workout
    else
      # Step 2: If exercise selected, show machine picker
      if params[:select_exercise].present?
        @selected_exercise = Exercise.for_user(Current.user).find(params[:select_exercise])
        @machines = @workout.gym.machines.ordered
      else
        # Step 1: Show exercise list
        @exercises = Exercise.for_user(Current.user)
        @exercises = @exercises.where("LOWER(name) LIKE LOWER(?)", "%#{params[:search]}%") if params[:search].present?
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

      redirect_to new_workout, notice: "Workout copied! Ready to go! 💪"
    else
      redirect_to @workout, alert: "Could not copy workout."
    end
  end

  private

  def add_exercise_to_workout
    exercise = Exercise.for_user(Current.user).find(params[:exercise_id])
    machine = params[:machine_id].present? ? @workout.gym&.machines&.find(params[:machine_id]) : nil

    # Create a new block for this exercise
    block = @workout.workout_blocks.create!(
      position: @workout.workout_blocks.count + 1,
      rest_seconds: 90
    )

    workout_exercise = block.workout_exercises.create!(
      exercise: exercise,
      machine: machine,
      position: 1
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
end
