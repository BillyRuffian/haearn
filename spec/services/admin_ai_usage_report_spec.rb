require 'rails_helper'

RSpec.describe Admin::AiUsageReport do
  let(:through) { Time.zone.local(2026, 9, 15, 12) }
  let(:usage) { { input_tokens: 1_000_000, input_tokens_details: { cached_tokens: 400_000 },
    output_tokens: 100_000, output_tokens_details: { reasoning_tokens: 80_000 } } }

  def analysis(model: 'gpt-5-mini', tokens: usage, at: through, status: 'completed')
    WorkoutAnalysis.create!(workout: workouts(:one), workout_finished_at: workouts(:one).finished_at,
      model: model, prompt_version: 'workout-v1', request_key: SecureRandom.uuid,
      status: status, token_usage: tokens, created_at: at)
  end

  it 'uses cached input discounts and counts output reasoning once across both review types' do
    analysis
    WeeklyTrainingReview.create!(user: users(:one), week_start: Date.new(2026, 8, 3), model: 'gpt-5-mini-2025-08-07',
      prompt_version: 'weekly-v1', status: 'failed', token_usage: usage, created_at: through)
    result = described_class.new(through: through).call
    # 600k uncached = $0.15, 400k cached = $0.01, 100k output (including reasoning) = $0.20.
    expect(result[:estimated_cost_usd]).to eq(BigDecimal('0.72'))
    expect(result[:priced_reviews]).to eq(2)
    expect(result[:rows].map { |row| row[:feature] }).to eq([ 'Workout coaching', 'Weekly reviews' ])
    expect(result[:rows].map { |row| row[:output_tokens] }).to eq([ 100_000, 100_000 ])
  end

  it 'reports missing/invalid usage and unpriced models separately instead of assuming zero cost' do
    analysis(tokens: nil, status: 'failed')
    analysis(tokens: {})
    analysis(tokens: { input_tokens: 100 })
    analysis(tokens: { input_tokens: '100', output_tokens: 2 })
    analysis(tokens: { input_tokens: 100, output_tokens: -1 })
    analysis(tokens: { input_tokens: 100, output_tokens: 2, input_tokens_details: { cached_tokens: 101 } })
    analysis(model: 'unverified-model')
    result = described_class.new(through: through).call
    expect(result[:estimated_cost_usd]).to be_nil
    expect(result[:missing_usage_reviews]).to eq(6)
    expect(result[:unpriced_reviews]).to eq(1)
    expect(result[:priced_reviews]).to eq(0)
    expect(result[:rows].find { |row| row[:model] == 'unverified-model' }[:input_tokens]).to eq(1_000_000)
  end

  it 'distinguishes genuine zero usage from unavailable usage and accepts absent cache details' do
    analysis(tokens: { input_tokens: 0, output_tokens: 0 })
    expect(described_class.new(through: through).call[:estimated_cost_usd]).to eq(0)
    analysis(tokens: { input_tokens: 1_000_000, output_tokens: 0 })
    expect(described_class.new(through: through).call[:estimated_cost_usd]).to eq(BigDecimal('0.25'))
  end

  it 'only includes reviews requested within the stated period regardless of later updates' do
    analysis(at: through - 30.days - 1.second)
    analysis(at: through + 1.second)
    analysis(at: through - 30.days)
    result = described_class.new(through: through).call
    expect(result[:priced_reviews]).to eq(1)
    expect(result[:estimated_cost_usd]).to eq(BigDecimal('0.36'))
  end

  it 'returns an empty state and keeps query counts constant as review history grows' do
    expect(described_class.new(through: through).call[:rows]).to be_empty
    count_queries = lambda do
      count = 0
      callback = ->(_name, _start, _finish, _id, payload) { count += 1 if payload[:sql].match?(/\ASELECT/i) && payload[:name] != 'SCHEMA' }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.new(through: through).call }
      count
    end
    expect(count_queries.call).to eq(2)
    10.times { analysis }
    expect(count_queries.call).to eq(2)
  end
end
