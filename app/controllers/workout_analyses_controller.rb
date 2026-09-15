class WorkoutAnalysesController < ApplicationController
  before_action :set_workout

  def index
    @analysis = @workout.workout_analyses.newest_first.first
    render_panel
  end

  def show
    @analysis = @workout.workout_analyses.find(params[:id])
    render_panel
  end

  def create
    analysis = Ai::RequestWorkoutAnalysis.call(@workout)
    message = analysis.failed? ? 'Coaching could not be queued. Please retry.' : 'AI coaching queued.'
    redirect_to workout_path(@workout, anchor: 'ai-coaching'), notice: message, status: :see_other
  end

  private

  def set_workout
    @workout = Current.user.workouts.completed.find(params[:workout_id])
  end

  def render_panel
    response.headers['Cache-Control'] = 'no-store'
    render partial: 'workout_analyses/panel', locals: { workout: @workout, analysis: @analysis, live: action_name == 'index' }
  end
end
