# User preferences and data export functionality
# Manages preferred units, rest timers, password changes, and workout data exports
class SettingsController < ApplicationController
  before_action :set_user

  # GET /settings
  # Shows settings page with preferences and export options
  def show
  end

  def update
    if @user.update(user_params)
      redirect_to settings_path, notice: 'Settings updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  # PATCH /settings/update_password
  # Changes user password with current password verification
  def update_password
    # Verify current password before allowing change
    unless @user.authenticate(params[:current_password])
      @user.errors.add(:current_password, 'is incorrect')
      render :show, status: :unprocessable_entity
      return
    end

    if params[:password].blank?
      @user.errors.add(:password, "can't be blank")
      render :show, status: :unprocessable_entity
      return
    end

    if @user.update(password_params)
      redirect_to settings_path, notice: 'Password changed successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  # GET /settings/export_data
  # Exports all user data as JSON (gyms, exercises, workouts, sets)
  # Useful for data portability and backups
  def export_data
    data = {
      exported_at: Time.current.iso8601,
      user: {
        email: @user.email_address,
        name: @user.name,
        preferred_unit: @user.preferred_unit,
        default_rest_seconds: @user.default_rest_seconds
      },
      gyms: export_gyms,
      exercises: export_exercises,
      workouts: export_workouts
    }

    send_data data.to_json,
              filename: "haearn-export-#{Date.current}.json",
              type: 'application/json',
              disposition: 'attachment'
  end

  # GET /settings/export_csv
  # Exports workout history as CSV for analysis in Excel/Google Sheets
  def export_csv
    csv_data = generate_workouts_csv

    send_data csv_data,
              filename: "haearn-workouts-#{Date.current}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  # GET /settings/export_prs
  # Exports personal records as CSV
  def export_prs
    csv_data = generate_prs_csv

    send_data csv_data,
              filename: "haearn-prs-#{Date.current}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  private

  def set_user
    @user = Current.user
  end

  def user_params
    params.require(:user).permit(
      :name,
      :email_address,
      :preferred_unit,
      :default_rest_seconds,
      :default_gym_id,
      :weekly_summary_email,
      :progression_rep_target,
      :notify_readiness,
      :notify_plateau,
      :notify_streak_risk,
      :notify_volume_drop,
      :notify_rest_timer_in_app,
      :notify_rest_timer_push
    )
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end

  def export_gyms
    @user.gyms.includes(:machines).map do |gym|
      {
        name: gym.name,
        notes: gym.notes,
        machines: gym.machines.map do |m|
          {
            name: m.name,
            equipment_type: m.equipment_type,
            weight_ratio: m.weight_ratio,
            display_unit: m.display_unit,
            notes: m.notes
          }
        end
      }
    end
  end

  def export_exercises
    @user.exercises.map do |exercise|
      {
        name: exercise.name,
        exercise_type: exercise.exercise_type,
        has_weight: exercise.has_weight,
        description: exercise.description
      }
    end
  end

  def export_workouts
    @user.workouts.includes(
      :gym,
      workout_blocks: {
        workout_exercises: [ :exercise, :machine, :exercise_sets ]
      }
    ).order(started_at: :desc).map do |workout|
      {
        gym: workout.gym&.name,
        started_at: workout.started_at&.iso8601,
        finished_at: workout.finished_at&.iso8601,
        notes: workout.notes,
        blocks: workout.workout_blocks.map do |block|
          {
            position: block.position,
            rest_seconds: block.rest_seconds,
            exercises: block.workout_exercises.map do |we|
              {
                exercise: we.exercise&.name,
                machine: we.machine&.name,
                position: we.position,
                session_notes: we.session_notes,
                persistent_notes: we.persistent_notes,
                sets: we.exercise_sets.map do |s|
                  {
                    position: s.position,
                    weight_kg: s.weight_kg&.to_f,
                    reps: s.reps,
                    duration_seconds: s.duration_seconds,
                    distance_meters: s.distance_meters&.to_f,
                    is_warmup: s.is_warmup,
                    completed_at: s.completed_at&.iso8601
                  }
                end
              }
            end
          }
        end
      }
    end
  end

  def generate_workouts_csv
    workouts = @user.workouts.includes(
      :gym,
      workout_blocks: {
        workout_exercises: [ :exercise, :machine, :exercise_sets ]
      }
    ).order(started_at: :desc)

    CSV.generate(headers: true) do |csv|
      csv << [
        'Date', 'Gym', 'Exercise', 'Machine', 'Set #', 'Weight (kg)',
        'Reps', 'Duration (s)', 'Distance (m)', 'Warmup', 'Volume (kg)',
        'Workout Notes', 'Session Notes'
      ]

      workouts.each do |workout|
        workout.workout_blocks.each do |block|
          block.workout_exercises.each do |we|
            we.exercise_sets.each do |set|
              volume = (set.weight_kg || 0) * (set.reps || 0)
              csv << [
                workout.started_at&.strftime('%Y-%m-%d'),
                workout.gym&.name,
                we.exercise&.name,
                we.machine&.name,
                set.position,
                set.weight_kg&.to_f,
                set.reps,
                set.duration_seconds,
                set.distance_meters&.to_f,
                set.is_warmup ? 'Yes' : 'No',
                volume.round(2),
                workout.notes,
                we.session_notes
              ]
            end
          end
        end
      end
    end
  end

  def generate_prs_csv
    # Get all exercises the user has done
    exercises_with_sets = Exercise.for_user(@user)
      .joins(workout_exercises: :exercise_sets)
      .joins('INNER JOIN workout_blocks ON workout_exercises.workout_block_id = workout_blocks.id')
      .joins('INNER JOIN workouts ON workout_blocks.workout_id = workouts.id')
      .where(workouts: { user_id: @user.id, finished_at: ..Time.current })
      .where(exercise_sets: { is_warmup: false })
      .distinct

    CSV.generate(headers: true) do |csv|
      csv << [
        'Exercise', 'PR Type', 'Value', 'Unit', 'Reps', 'Date', 'Gym', 'Machine'
      ]

      exercises_with_sets.each do |exercise|
        prs = calculate_exercise_prs(exercise)

        prs.each do |pr|
          csv << [
            exercise.name,
            pr[:type],
            pr[:value],
            pr[:unit],
            pr[:reps],
            pr[:date],
            pr[:gym],
            pr[:machine]
          ]
        end
      end
    end
  end

  def calculate_exercise_prs(exercise)
    prs = []

    # Get all working sets for this exercise
    sets = @user.exercise_sets
      .joins(workout_exercise: { workout_block: :workout })
      .includes(workout_exercise: [ :machine, { workout_block: { workout: :gym } } ])
      .where.not(workouts: { finished_at: nil })
      .where(workout_exercises: { exercise_id: exercise.id })
      .where(is_warmup: false)

    # Heaviest weight PR
    if exercise.has_weight?
      heaviest_set = sets.where.not(weight_kg: nil).order(weight_kg: :desc).first
      if heaviest_set
        weight = @user.preferred_unit == 'lbs' ? (heaviest_set.weight_kg * 2.20462).round(1) : heaviest_set.weight_kg.round(1)
        workout = heaviest_set.workout_exercise.workout_block.workout
        prs << {
          type: 'Heaviest Weight',
          value: weight,
          unit: @user.preferred_unit,
          reps: heaviest_set.reps,
          date: workout.started_at&.strftime('%Y-%m-%d'),
          gym: workout.gym&.name,
          machine: heaviest_set.workout_exercise.machine&.name
        }
      end

      # Best single set volume (weight × reps)
      best_volume_set = sets.where.not(weight_kg: nil).where.not(reps: nil)
        .select { |s| (s.weight_kg || 0) * (s.reps || 0) > 0 }
        .max_by { |s| s.weight_kg * s.reps }

      if best_volume_set
        volume_kg = best_volume_set.weight_kg * best_volume_set.reps
        volume = @user.preferred_unit == 'lbs' ? (volume_kg * 2.20462).round(1) : volume_kg.round(1)
        workout = best_volume_set.workout_exercise.workout_block.workout
        prs << {
          type: 'Best Set Volume',
          value: volume,
          unit: @user.preferred_unit,
          reps: best_volume_set.reps,
          date: workout.started_at&.strftime('%Y-%m-%d'),
          gym: workout.gym&.name,
          machine: best_volume_set.workout_exercise.machine&.name
        }
      end
    end

    # Most reps (for exercises that track reps)
    if exercise.reps?
      most_reps_set = sets.where.not(reps: nil).order(reps: :desc).first
      if most_reps_set
        workout = most_reps_set.workout_exercise.workout_block.workout
        prs << {
          type: 'Most Reps',
          value: most_reps_set.reps,
          unit: 'reps',
          reps: nil,
          date: workout.started_at&.strftime('%Y-%m-%d'),
          gym: workout.gym&.name,
          machine: most_reps_set.workout_exercise.machine&.name
        }
      end
    end

    # Longest duration (for time-based exercises)
    if exercise.time?
      longest_set = sets.where.not(duration_seconds: nil).order(duration_seconds: :desc).first
      if longest_set
        workout = longest_set.workout_exercise.workout_block.workout
        prs << {
          type: 'Longest Duration',
          value: longest_set.duration_seconds,
          unit: 'seconds',
          reps: nil,
          date: workout.started_at&.strftime('%Y-%m-%d'),
          gym: workout.gym&.name,
          machine: longest_set.workout_exercise.machine&.name
        }
      end
    end

    prs
  end
end
