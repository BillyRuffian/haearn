require 'rails_helper'

RSpec.describe AnalyseWorkoutJob, type: :job do
  include_context 'AI coaching'

  let(:workout) { coaching_workout }
  let(:analysis) { workout.workout_analyses.sole }
  let(:context) { Ai::WorkoutContextBuilder.new(workout).call }
  let(:data) { coaching_response(context) }

  it 'sends a strict Responses request and persists validated results and usage once' do
    analysis
    expect(OpenAI::Client).to receive(:new).with(api_key: 'test-key-never-sent', timeout: 90, max_retries: 0).and_return(openai_sdk)
    expect(responses_api).to receive(:create).once do |request|
      expect(request).to include(model: 'gpt-5-mini', store: false, max_output_tokens: 6000)
      expect(request[:instructions]).to include('One weak session is not a plateau')
      expect(request.dig(:text, :format)).to include(type: :json_schema, strict: true, schema: Ai::WorkoutAnalysisSchema::SCHEMA)
      expect(JSON.parse(request[:input])).to eq(context)
      api_response(data)
    end

    expect { 2.times { described_class.perform_now(analysis.id) } }.not_to change(WorkoutAnalysis, :count)
    expect(analysis.reload).to have_attributes(status: 'completed', summary: data.dig('overall', 'summary'),
      response_data: data, input_data: context, response_id: 'resp_coaching_test')
    expect(analysis.analysed_at).to be_present
    expect(analysis.token_usage).to include('input_tokens' => 1000, 'output_tokens' => 200)
    expect(workout.reload).to be_completed
  end

  it 'allows nullable next-session recommendations' do
    nullable = coaching_response(context, nullable: true)
    allow(responses_api).to receive(:create).and_return(api_response(nullable))
    described_class.perform_now(analysis.id)
    expect(analysis.reload).to be_completed
    expect(analysis.response_data['exercise_feedback'].sole['next_session'].values).to all(be_nil)
  end

  it 'records missing configuration without making an API request' do
    ENV.delete('OPENAI_API_KEY')
    allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
    expect(responses_api).not_to receive(:create)
    described_class.perform_now(analysis.id)
    expect(analysis.reload).to have_attributes(status: 'failed', error_message: 'not_configured')
    expect(workout.reload).to be_completed
  end

  it 'prevents a superseded worker from publishing output or metadata' do
    target = analysis
    allow(responses_api).to receive(:create) do
      target.reload.fail_safely!('superseded_or_interrupted')
      Ai::WorkoutAnalyser.call(workout)
      api_response(data)
    end
    described_class.perform_now(target.id)
    expect(target.reload).to be_failed
    expect(target.response_data).to be_nil
    expect(target.response_id).to be_nil
    expect(workout.workout_analyses.newest_first.first).to be_pending
  end

  it 'retries a transient failure on the same record and succeeds without duplicate versions' do
    target = analysis
    clear_enqueued_jobs
    attempts = 0
    allow(responses_api).to receive(:create) do
      attempts += 1
      raise OpenAI::Errors::APITimeoutError.new(url: URI('https://api.openai.com/v1/responses')) if attempts == 1

      api_response(data)
    end
    expect do
      perform_enqueued_jobs { described_class.perform_later(target.id) }
    end.not_to change(WorkoutAnalysis, :count)
    expect(attempts).to eq(2)
    expect(target.reload).to be_completed
  end

  it 'stops rate-limit retries and records failure without changing the workout' do
    target = analysis
    clear_enqueued_jobs
    error = OpenAI::Errors::RateLimitError.new(url: URI('https://api.openai.com/v1/responses'), status: 429,
      headers: {}, body: nil, request: nil, response: nil,
      message: 'secret body must never be persisted')
    allow(responses_api).to receive(:create).and_raise(error)
    expect do
      perform_enqueued_jobs { described_class.perform_later(target.id) }
    end.not_to change(WorkoutAnalysis, :count)
    expect(responses_api).to have_received(:create).exactly(3).times
    expect(target.reload).to have_attributes(status: 'failed', error_message: 'RateLimitError')
    expect(workout.reload).to be_completed
  end

  it 'fails authentication permanently without retrying or exposing the API message' do
    error = OpenAI::Errors::AuthenticationError.new(url: URI('https://api.openai.com/v1/responses'), status: 401,
      headers: {}, body: nil, request: nil, response: nil, message: 'private key')
    allow(responses_api).to receive(:create).and_raise(error)
    target = analysis
    clear_enqueued_jobs
    described_class.perform_now(target.id)
    expect(target.reload).to have_attributes(status: 'failed', error_message: 'AuthenticationError')
    expect(enqueued_jobs).to be_empty
  end

  it 'rejects malformed, refused, incomplete, wrongly scoped and schema-invalid responses' do
    variants = [
      api_response(nil, content: [ { type: 'output_text', text: '{invalid', annotations: [] } ]),
      api_response(nil, content: [ { type: 'refusal', refusal: 'Cannot comply' } ]),
      api_response(data, status: 'incomplete'),
      api_response(data.deep_merge('overall' => { 'rating' => 'invented' })),
      api_response(data.deep_merge('exercise_feedback' => []))
    ]
    variants.each do |response|
      target = Ai::WorkoutAnalyser.call(workout)
      allow(responses_api).to receive(:create).and_return(response)
      described_class.perform_now(target.id)
      expect(target.reload).to be_failed
      expect(target.response_data).to be_nil
      expect(target.summary).to be_nil
    end
  end

  it 'ignores active claims, recovers stale ones, and stops if the workout was continued' do
    target = analysis
    target.update!(status: 'processing', processing_token: 'other-worker')
    expect(responses_api).not_to receive(:create)
    described_class.perform_now(target.id)
    expect(target.reload).to be_processing
    workout.update!(finished_at: nil)
    described_class.perform_now(target.id)
    expect(target.reload).to have_attributes(status: 'failed', error_message: 'workout_changed')
  end

  it 'recovers a stale processing claim and retains completed history on reanalysis' do
    target = analysis
    target.update!(status: 'processing', processing_token: 'old', updated_at: 20.minutes.ago)
    allow(responses_api).to receive(:create).and_return(api_response(data))
    described_class.perform_now(target.id)
    expect(target.reload).to be_completed
    newer = Ai::WorkoutAnalyser.call(workout)
    expect(newer.id).not_to eq(target.id)
    expect(workout.workout_analyses.count).to eq(2)
    expect(target.reload.response_data).to eq(data)
    expect(Ai::WorkoutAnalyser.call(workout).id).to eq(newer.id)
  end
end
