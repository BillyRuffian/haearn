module AiCoachingHelpers
  def coaching_workout(user: users(:one), exercise: exercises(:bench_press), machine: nil,
    at: Time.utc(2026, 9, 14, 10), reps: [ 10, 10, 10, 9 ], weight: 37.5, finish: true)
    gym = user.gyms.first
    workout = user.workouts.create!(gym: gym, started_at: at)
    block = workout.workout_blocks.create!(position: 1)
    entry = block.workout_exercises.create!(exercise: exercise, machine: machine)
    reps.each_with_index do |rep_count, index|
      entry.exercise_sets.create!(weight_kg: weight, reps: rep_count, position: index + 1,
        is_warmup: false, completed_at: at + (index + 1).minutes)
    end
    workout.update!(finished_at: at + 1.hour) if finish
    workout
  end

  def coaching_response(context, nullable: false)
    {
      'overall' => { 'rating' => 'good', 'summary' => 'You added useful reps. Keep building consistently.', 'confidence' => 'medium' },
      'exercise_feedback' => context.fetch('exercises').map do |exercise|
        { 'exercise_id' => exercise['exercise_id'], 'machine_id' => exercise['machine_id'],
          'exercise_name' => exercise['exercise_name'],
          'status' => exercise['history'].empty? || exercise['sets'].empty? ? 'insufficient_data' : 'progressing',
          'summary' => 'Keep the load and build toward your rep target.',
          'observations' => [ 'Consistent working sets.' ],
          'next_session' => { 'weight_kg' => nullable ? nil : 37.5, 'sets' => nullable ? nil : 4,
            'target_reps' => nullable ? nil : [ 10, 10, 10, 10 ], 'instruction' => nullable ? nil : 'Keep this weight and aim for four sets of ten.' } }
      end,
      'workout_observations' => [ 'Keep the same exercise selection.' ],
      'programme_recommendations' => []
    }
  end

  def api_response(data, status: 'completed', content: nil)
    OpenAI::Models::Responses::Response.new(
      id: 'resp_coaching_test', status: status,
      output: [ { type: 'message', role: 'assistant', id: 'msg_test', status: 'completed',
        content: content || [ { type: 'output_text', text: JSON.generate(data), annotations: [] } ] } ],
      usage: { input_tokens: 1000, output_tokens: 200, total_tokens: 1200,
        input_tokens_details: { cached_tokens: 100 }, output_tokens_details: { reasoning_tokens: 20 } }
    )
  end
end

RSpec.shared_context 'AI coaching' do
  include AiCoachingHelpers
  include ActiveJob::TestHelper

  let(:responses_api) { instance_double(OpenAI::Resources::Responses) }
  let(:openai_sdk) { instance_double(OpenAI::Client, responses: responses_api) }

  around do |example|
    original_key = ENV['OPENAI_API_KEY']
    original_adapter = ActiveJob::Base.queue_adapter
    ENV['OPENAI_API_KEY'] = 'test-key-never-sent'
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ENV['OPENAI_API_KEY'] = original_key
    ActiveJob::Base.queue_adapter = original_adapter
  end

  before do
    clear_enqueued_jobs
    clear_performed_jobs
    allow(OpenAI::Client).to receive(:new).and_return(openai_sdk)
  end
end
