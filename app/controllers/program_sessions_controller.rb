class ProgramSessionsController < ApplicationController
  before_action :set_training_program
  before_action :set_program_session, only: %i[edit update destroy]

  def new
    @program_session = @training_program.program_sessions.build(
      week_number: params[:week_number],
      weekday: params[:weekday],
      volume_percent: 100,
      intensity_percent: 100
    )
    @templates = Current.user.workout_templates.ordered
  end

  def create
    @program_session = @training_program.program_sessions.build(program_session_params)

    if @program_session.save
      redirect_to @training_program, notice: 'Session added to the program.'
    else
      redirect_to @training_program, alert: @program_session.errors.full_messages.to_sentence
    end
  end

  def edit
    @templates = Current.user.workout_templates.ordered
  end

  def update
    if @program_session.update(program_session_params)
      redirect_to @training_program, notice: 'Program session updated.'
    else
      @templates = Current.user.workout_templates.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @program_session.destroy
      redirect_to @training_program, notice: 'Session removed from the program.'
    else
      redirect_to @training_program, alert: @program_session.errors.full_messages.to_sentence
    end
  end

  private

  def set_training_program
    @training_program = Current.user.training_programs.available.find(params[:training_program_id])
  end

  def set_program_session
    @program_session = @training_program.program_sessions.find(params[:id])
  end

  def program_session_params
    params.require(:program_session).permit(
      :workout_template_id,
      :name,
      :notes,
      :week_number,
      :weekday,
      :volume_percent,
      :intensity_percent
    )
  end
end
