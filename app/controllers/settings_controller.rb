class SettingsController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to settings_path, notice: 'Settings updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
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

  def export_csv
    csv_data = generate_workouts_csv

    send_data csv_data,
              filename: "haearn-workouts-#{Date.current}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  private

  def set_user
    @user = Current.user
  end

  def user_params
    params.require(:user).permit(:name, :email_address, :preferred_unit, :default_rest_seconds)
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
end
