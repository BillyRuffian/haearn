class TodaysSessionsController < ApplicationController
  before_action :set_active_cycle
  before_action :set_scheduled_session, only: %i[start skip restore]

  def show
    @date = Date.current
    @gyms = Current.user.gyms.ordered
    return unless @program_cycle

    @program_sessions = @program_cycle.scheduled_sessions_on(@date)
    @prescriptions = @program_sessions.index_with do |program_session|
      ProgramPrescription.new(program_session: program_session).rows
    end
    @executions = @program_cycle.program_session_executions
      .where(program_session_id: @program_sessions.map(&:id))
      .includes(workout: { workout_exercises: :exercise_sets })
      .index_by(&:program_session_id)
  end

  def start
    existing_execution = @program_cycle.program_session_executions.find_by(program_session: @program_session)
    if existing_execution&.workout
      redirect_to existing_execution.workout
      return
    end

    if (active_workout = Current.user.active_workout)
      redirect_to active_workout, alert: 'Finish the active workout before starting today’s prescription.'
      return
    end

    gym = Current.user.gyms.find(start_params[:gym_id].presence || Current.user.default_gym_id)
    execution = nil
    workout = nil

    ProgramSessionExecution.transaction do
      execution = prepare_execution(status: 'in_progress')
      workout = WorkoutTemplateInstantiator.new(
        user: Current.user,
        workout_template: @program_session.workout_template,
        gym: gym,
        program_session_execution: execution
      ).call
    end

    redirect_to workout, notice: "Started #{execution.program_session.display_name}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to today_session_path, alert: error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotFound
    redirect_to today_session_path, alert: 'Select one of your gyms before starting.'
  end

  def skip
    execution = build_execution
    if execution.workout
      redirect_to execution.workout, alert: 'A workout already exists for this prescription.'
      return
    end

    execution.assign_attributes(
      status: 'skipped',
      skip_reason: skip_params[:skip_reason],
      skip_notes: skip_params[:skip_notes],
      completed_at: Time.current
    )
    apply_prescription(execution)
    execution.save!

    redirect_to today_session_path, notice: "Skipped #{@program_session.display_name}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to today_session_path, alert: error.record.errors.full_messages.to_sentence
  end

  def restore
    execution = @program_cycle.program_session_executions.find_by!(program_session: @program_session, status: 'skipped')
    execution.destroy!
    redirect_to today_session_path, notice: "Restored #{@program_session.display_name}."
  end

  private

  def set_active_cycle
    @program_cycle = Current.user.active_program_cycle
  end

  def set_scheduled_session
    raise ActiveRecord::RecordNotFound unless @program_cycle

    @program_session = @program_cycle.scheduled_sessions_on(Date.current).find(params[:program_session_id])
  end

  def build_execution
    @program_cycle.program_session_executions.find_or_initialize_by(program_session: @program_session) do |execution|
      execution.scheduled_on = @program_cycle.scheduled_on(@program_session)
      execution.volume_percent = @program_session.volume_percent
      execution.intensity_percent = @program_session.intensity_percent
      execution.session_name = @program_session.display_name
      execution.workout_template_name = @program_session.workout_template.name
    end
  end

  def prepare_execution(status:)
    execution = build_execution
    execution.assign_attributes(
      status: status,
      skip_reason: nil,
      skip_notes: nil,
      completed_at: nil,
      volume_percent: start_params[:volume_percent].presence || @program_session.volume_percent,
      intensity_percent: start_params[:intensity_percent].presence || @program_session.intensity_percent,
      adjustment_reason: start_params[:adjustment_reason].presence,
      adjustment_notes: start_params[:adjustment_notes].presence
    )
    apply_prescription(execution)
    execution.save!
    execution
  end

  def apply_prescription(execution)
    prescription = ProgramPrescription.new(
      program_session: @program_session,
      volume_percent: execution.volume_percent,
      intensity_percent: execution.intensity_percent
    )
    execution.prescription = prescription.rows
    execution.prescribed_sets = prescription.prescribed_sets
    execution.prescribed_volume_kg = prescription.prescribed_volume_kg
  end

  def start_params
    params.fetch(:program_session_execution, ActionController::Parameters.new).permit(
      :gym_id,
      :volume_percent,
      :intensity_percent,
      :adjustment_reason,
      :adjustment_notes
    )
  end

  def skip_params
    params.require(:program_session_execution).permit(:skip_reason, :skip_notes)
  end
end
