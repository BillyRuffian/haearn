require 'rails_helper'

RSpec.describe 'Admin AI costs', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.zone.local(2026, 9, 15, 12)) { example.run }
  end

  it 'requires authentication and admin access' do
    get admin_root_path
    expect(response).to redirect_to(new_session_path)
    sign_in_as(users(:one))
    get admin_root_path
    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include('AI usage &amp; estimated costs')
  end

  it 'shows an honest empty state without calling the provider' do
    expect(OpenAI::Client).not_to receive(:new)
    sign_in_as(users(:admin))
    get admin_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No AI reviews requested in this period', 'not an invoice')
    expect(response.body).to include(Ai::TokenPricing::SOURCE_URL)
  end

  it 'renders known costs and unavailable pricing with accessible responsive tables and no private review data' do
    %w[gpt-5-mini unknown-model].each do |model|
      WorkoutAnalysis.create!(workout: workouts(:one), workout_finished_at: workouts(:one).finished_at,
        model: model, prompt_version: 'workout-v1', request_key: SecureRandom.uuid, status: 'completed',
        token_usage: { input_tokens: 1_000_000, output_tokens: 100_000, input_tokens_details: { cached_tokens: 400_000 } },
        input_data: { notes: 'private session notes' }, response_data: { summary: 'private coaching advice' })
    end
    expect(OpenAI::Client).not_to receive(:new)
    sign_in_as(users(:admin))
    get admin_root_path
    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body).at_css('#ai-costs')
    expect(html.text).to include('$0.3600', 'Unavailable', 'last 30 days', '400,000', 'unknown-model')
    expect(html.at_css('.table-responsive table caption')).to be_present
    expect(html.css('th[scope="row"]').size).to eq(2)
    expect(response.body).not_to include('private session notes', 'private coaching advice')
  end
end
