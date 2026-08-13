class TrainingProgramsController < ApplicationController
  before_action :set_training_program, only: %i[show edit update destroy activate complete]

  def index
    @training_programs = Current.user.training_programs.available
      .includes(:program_sessions, :program_cycles)
      .ordered
    @active_cycle = Current.user.active_program_cycle
  end

  def show
    @program_sessions = @training_program.program_sessions
      .includes(workout_template: { template_blocks: { template_exercises: [ :exercise, :machine ] } })
      .ordered
    @templates = Current.user.workout_templates.ordered
    @active_cycle = @training_program.program_cycles.active.recent.first
    @recent_cycles = @training_program.program_cycles.recent.limit(5)
  end

  def new
    @training_program = Current.user.training_programs.build(weeks_count: 4)
  end

  def create
    @training_program = Current.user.training_programs.build(training_program_params)

    if @training_program.save
      redirect_to @training_program, notice: 'Program created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @training_program.update(training_program_params)
      redirect_to @training_program, notice: 'Program updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @training_program.archive!
    redirect_to training_programs_path, notice: 'Program archived.'
  end

  def activate
    cycle = @training_program.activate!(starts_on: program_cycle_params[:starts_on])
    redirect_to today_session_path, notice: "#{@training_program.name} is active from #{cycle.starts_on.to_fs(:long)}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @training_program, alert: error.record.errors.full_messages.to_sentence
  end

  def complete
    cycle = @training_program.program_cycles.active.find(params[:cycle_id])
    cycle.complete!
    redirect_to @training_program, notice: 'Program cycle completed.'
  end

  private

  def set_training_program
    @training_program = Current.user.training_programs.available.find(params[:id])
  end

  def training_program_params
    params.require(:training_program).permit(:name, :description, :weeks_count)
  end

  def program_cycle_params
    params.require(:program_cycle).permit(:starts_on)
  end
end
