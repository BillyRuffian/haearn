require 'rails_helper'

RSpec.describe WeeklyTrainingReviewJob do
  include_context 'AI coaching'
  include ActiveSupport::Testing::TimeHelpers

  let(:week_start) { Date.new(2026, 9, 7) }
  let(:review) { WeeklyTrainingReview.request!(user: users(:one), week_start: week_start) }

  around do |example|
    travel_to(Time.zone.local(2026, 9, 15, 12))
    example.run
  ensure
    travel_back
  end

  before do
    users(:one).update!(weekly_summary_email: true)
    ActionMailer::Base.deliveries.clear
    coaching_workout(at: Time.utc(2026, 9, 8))
    allow(responses_api).to receive(:create) do |**request|
      api_response(weekly_response(JSON.parse(request.fetch(:input))))
    end
  end

  def weekly_response(context)
    data = coaching_response(context)
    data['weekly_observations'] = data.delete('workout_observations')
    data['next_week_priorities'] = [ 'Keep the controlled tempo next week.' ]
    data.delete('programme_recommendations')
    data
  end

  it 'creates one durable review per user and completed week across scheduler retries' do
    User.where.not(id: users(:one).id).update_all(weekly_summary_email: false)
    2.times { SendWeeklySummariesJob.perform_now(week_start) }
    expect(WeeklyTrainingReview.where(user: users(:one), week_start: week_start).count).to eq(1)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(responses_api).not_to have_received(:create)
    duplicate = review.attributes.except('id', 'created_at', 'updated_at')
    expect { WeeklyTrainingReview.insert_all!([ duplicate ]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'waits for persisted coaching and delivers both email parts once despite overlapping jobs' do
    allow(responses_api).to receive(:create) do |**request|
      expect(review.reload).to be_processing
      described_class.perform_now(review.id)
      DeliverWeeklySummaryJob.perform_now(review.id)
      expect(ActionMailer::Base.deliveries).to be_empty
      api_response(weekly_response(JSON.parse(request.fetch(:input))))
    end
    DeliverWeeklySummaryJob.perform_now(review.id)
    described_class.perform_now(review.id)
    expect(review.reload).to be_completed
    expect(review.response_id).to eq('resp_coaching_test')
    expect(responses_api).to have_received(:create).once
    allow_any_instance_of(Mail::TestMailer).to receive(:deliver!).and_wrap_original do |original, *args|
      expect(review.reload).to be_completed
      DeliverWeeklySummaryJob.perform_now(review.id)
      original.call(*args)
    end
    2.times { DeliverWeeklySummaryJob.perform_now(review.id) }
    described_class.perform_now(review.id)
    expect(review.reload).to be_delivery_sent
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    mail = ActionMailer::Base.deliveries.sole
    expect(mail.message_id).to include("weekly-review-#{review.id}")
    [ mail.html_part, mail.text_part ].each do |part|
      expect(part.body.decoded).to include('Keep the controlled tempo next week.', '37.5 kg', 'Confidence: medium')
    end
  end

  it 'reuses frozen statistics, notes and display units after a transient failure' do
    entry = users(:one).workouts.find_by(started_at: Time.utc(2026, 9, 8)).workout_exercises.sole
    entry.update!(session_notes: 'Slower descent and full range today')
    allow(responses_api).to receive(:create).and_raise(OpenAI::Errors::APIConnectionError.new(url: 'https://api.openai.com/v1/responses'))
    described_class.perform_now(review.id)
    frozen_input, frozen_summary = review.reload.input_data.deep_dup, review.summary_data.deep_dup
    expect(review).to be_pending
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(enqueued_jobs.none? { |job| job[:job] == DeliverWeeklySummaryJob }).to be(true)
    entry.update!(session_notes: 'Changed after the report snapshot')
    users(:one).update!(preferred_unit: 'lbs')
    coaching_workout(at: Time.utc(2026, 9, 9))
    described_class.perform_now(review.id)
    expect(responses_api).to have_received(:create).once
    allow(responses_api).to receive(:create) do |**request|
      expect(JSON.parse(request.fetch(:input))).to eq(frozen_input)
      api_response(weekly_response(frozen_input))
    end
    travel_to(review.retry_at + 1.second) { described_class.perform_now(review.id) }
    expect(review.reload.summary_data).to eq(frozen_summary)
    expect(review.input_data.to_json).to include('Slower descent and full range today')
    DeliverWeeklySummaryJob.perform_now(review.id)
    expect(ActionMailer::Base.deliveries.sole.text_part.body.decoded).to include('37.5 kg')
  end

  it 'falls back only after three persisted transient attempts and never regenerates for delivery' do
    allow(responses_api).to receive(:create).and_raise(OpenAI::Errors::APIConnectionError.new(url: 'https://api.openai.com/v1/responses'))
    3.times do |attempt|
      described_class.perform_now(review.id)
      review.reload
      if attempt < 2
        DeliverWeeklySummaryJob.perform_now(review.id)
        expect(ActionMailer::Base.deliveries).to be_empty
        travel_to(review.retry_at + 1.second)
      end
    end
    expect(review).to be_failed
    expect(review.attempts).to eq(3)
    2.times { described_class.perform_now(review.id) }
    DeliverWeeklySummaryJob.perform_now(review.id)
    expect(responses_api).to have_received(:create).exactly(3).times
    expect(ActionMailer::Base.deliveries.sole.text_part.body.decoded).to include('AI review was unavailable')
  end

  it 'rejects invalid model output and sends a statistics-only fallback without diagnostics' do
    allow(responses_api).to receive(:create).and_return(api_response({ 'bad' => 'private diagnostic' }))
    described_class.perform_now(review.id)
    expect(review.reload).to be_failed
    expect(review.error_message).to eq('schema_invalid')
    DeliverWeeklySummaryJob.perform_now(review.id)
    [ ActionMailer::Base.deliveries.sole.html_part, ActionMailer::Base.deliveries.sole.text_part ].each do |part|
      expect(part.body.decoded).to include('AI review was unavailable')
      expect(part.body.decoded).not_to include('schema_invalid', 'private diagnostic')
    end
  end

  it 'recovers a lost delivery enqueue using the saved review without another API request' do
    described_class.perform_now(review.id)
    clear_enqueued_jobs
    RecoverWeeklyTrainingReviewsJob.perform_now
    expect(enqueued_jobs).to include(hash_including(job: described_class, args: [ review.id ]))
    described_class.perform_now(review.id)
    expect(enqueued_jobs).to include(hash_including(job: DeliverWeeklySummaryJob, args: [ review.id ]))
    expect(responses_api).to have_received(:create).once
  end

  it 'recovers stale processing and prevents the original worker from overwriting the replacement' do
    calls = 0
    allow(responses_api).to receive(:create) do |**request|
      calls += 1
      response = weekly_response(JSON.parse(request.fetch(:input)))
      if calls == 1
        review.update_columns(updated_at: 11.minutes.ago)
        described_class.perform_now(review.id)
        response['overall']['summary'] = 'Obsolete worker response'
      else
        response['overall']['summary'] = 'Replacement worker response'
      end
      api_response(response)
    end
    described_class.perform_now(review.id)
    expect(review.reload).to be_completed
    expect(review.attempts).to eq(2)
    expect(review.response_data.dig('overall', 'summary')).to eq('Replacement worker response')
  end

  it 'does not restart a fourth API attempt after a worker dies during the third attempt' do
    described_class.perform_now(review.id)
    review.update!(status: 'processing', attempts: 3, processing_token: 'dead', updated_at: 11.minutes.ago)
    described_class.perform_now(review.id)
    expect(review.reload).to be_failed
    expect(responses_api).to have_received(:create).once
  end

  it 'honors an opt-out that occurs while the AI request is in flight' do
    allow(responses_api).to receive(:create) do |**request|
      users(:one).update!(weekly_summary_email: false)
      api_response(weekly_response(JSON.parse(request.fetch(:input))))
    end
    described_class.perform_now(review.id)
    DeliverWeeklySummaryJob.perform_now(review.id)
    expect(review.reload).to be_delivery_skipped
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it 'does not automatically resend after an ambiguous SMTP failure or interrupted sending claim' do
    described_class.perform_now(review.id)
    allow_any_instance_of(Mail::TestMailer).to receive(:deliver!).and_raise(Timeout::Error)
    DeliverWeeklySummaryJob.perform_now(review.id)
    expect(review.reload).to be_delivery_uncertain
    clear_enqueued_jobs
    RecoverWeeklyTrainingReviewsJob.perform_now
    DeliverWeeklySummaryJob.perform_now(review.id)
    expect(enqueued_jobs).to be_empty
    review.update!(delivery_status: 'sending', delivery_started_at: 11.minutes.ago, processing_token: 'interrupted')
    RecoverWeeklyTrainingReviewsJob.perform_now
    expect(review.reload).to be_delivery_uncertain
    expect(enqueued_jobs).to be_empty
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it 'keeps a statistics failure recoverable and refuses to deliver an empty report' do
    allow_any_instance_of(WeeklySummaryCalculator).to receive(:calculate).and_raise(ActiveRecord::StatementInvalid)
    described_class.perform_now(review.id)
    expect(review.reload).to be_pending
    expect(review.summary_data).to be_nil
    DeliverWeeklySummaryJob.perform_now(review.id)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(responses_api).not_to have_received(:create)
  end
end
