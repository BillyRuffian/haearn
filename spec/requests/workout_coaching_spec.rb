require 'rails_helper'

RSpec.describe 'Workout coaching', type: :request do
  include_context 'AI coaching'
  let(:user) { users(:one) }
  before { sign_in_as(user) }

  it 'queues completion once, preserves logging on enqueue failure, and allows a later retry' do
    workout = coaching_workout(finish: false)
    clear_enqueued_jobs
    expect { patch finish_workout_path(workout) }.to have_enqueued_job(AnalyseWorkoutJob).exactly(:once)
    expect(response).to redirect_to(workout_path(workout))
    expect(workout.reload).to be_completed
    finished_at = workout.finished_at
    expect { patch finish_workout_path(workout) }.not_to have_enqueued_job(AnalyseWorkoutJob)
    expect(workout.reload.finished_at).to eq(finished_at)
    expect(workout.workout_analyses.count).to eq(1)

    next_workout = coaching_workout(finish: false)
    allow(ActiveJob::Base.queue_adapter).to receive(:enqueue).and_raise(ActiveJob::EnqueueError, 'queue unavailable')
    patch finish_workout_path(next_workout)
    expect(response).to redirect_to(workout_path(next_workout))
    expect(next_workout.reload).to be_completed
    expect(next_workout.workout_analyses.sole).to have_attributes(status: 'failed', error_message: 'enqueue_failed')
  end

  it 'renders pending, processing, completed, and failed states without raw diagnostic details' do
    workout = coaching_workout
    analysis = workout.workout_analyses.sole
    get workout_path(workout)
    expect(response.body).to include('AI Coaching', 'Coaching queued.', 'data-coaching-refresh-active-value="true"')
    expect(response.body).to include('turbo-cable-stream-source', 'signed-stream-name', "coaching_signal_workout_#{workout.id}")
    expect(Nokogiri::HTML(response.body).at_css('#ai-coaching [role="status"] .spinner-border.text-rust')).to be_present
    analysis.update!(status: 'processing')
    get workout_workout_analyses_path(workout)
    expect(response.body).to include('Analysing your workout')

    analysis.update!(status: 'pending')
    data = coaching_response(Ai::WorkoutContextBuilder.new(workout).call)
    allow(responses_api).to receive(:create).and_return(api_response(data))
    AnalyseWorkoutJob.perform_now(analysis.id)
    get workout_path(workout)
    expect(response.body).to include(data.dig('overall', 'summary'), 'Next session', '37.5 kg', 'Reanalyse workout')
    expect(response.body).not_to include('"exercise_feedback"')

    post workout_workout_analyses_path(workout)
    newer = workout.workout_analyses.newest_first.first
    newer.fail_safely!('AuthenticationError private diagnostic')
    get workout_workout_analyses_path(workout)
    expect(response.body).to include('Retry coaching', 'Previous analyses')
    expect(response.body).not_to include('AuthenticationError', 'private diagnostic')
    post workout_workout_analyses_path(workout)
    expect(response).to have_http_status(:see_other)
    expect(workout.workout_analyses.count).to eq(3)
    expect(analysis.reload).to be_completed
  end

  it 'scopes all coaching endpoints to the current user and completed workouts' do
    foreign = coaching_workout(user: users(:two))
    analysis = foreign.workout_analyses.sole
    get workout_workout_analyses_path(foreign)
    expect(response).to have_http_status(:not_found)
    post workout_workout_analyses_path(foreign)
    expect(response).to have_http_status(:not_found)
    own = coaching_workout
    get workout_workout_analysis_path(own, analysis)
    expect(response).to have_http_status(:not_found)
    active = coaching_workout(finish: false)
    post workout_workout_analyses_path(active)
    expect(response).to have_http_status(:not_found)
    get workout_path(active)
    expect(response.body).not_to include('AI Coaching')
  end
end
