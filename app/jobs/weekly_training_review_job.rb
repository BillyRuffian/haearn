class WeeklyTrainingReviewJob < ApplicationJob
  queue_as :default
  MAX_ATTEMPTS = 3

  def perform(review_id)
    review = WeeklyTrainingReview.find_by(id: review_id)
    return unless review&.delivery_pending?

    unless review.user.weekly_summary_email?
      WeeklyTrainingReview.where(id: review.id, delivery_status: 'pending').update_all(delivery_status: 'skipped', updated_at: Time.current)
      return
    end

    prepare_review(review) unless review.completed? || review.failed?
    review.reload
    DeliverWeeklySummaryJob.perform_later(review.id) if review.ready_to_send? && review.delivery_pending?
  end

  private

  def prepare_review(review)
    token = SecureRandom.uuid
    pending = WeeklyTrainingReview.where(id: review.id, status: 'pending').where('retry_at IS NULL OR retry_at <= ?', Time.current)
    stale = WeeklyTrainingReview.where(id: review.id, status: 'processing', updated_at: ..Ai::Config.processing_lease.ago)
    claim = pending.or(stale).where(delivery_status: 'pending')
    return unless claim.update_all(status: 'processing', processing_token: token, updated_at: Time.current) == 1

    review.reload
    owned = WeeklyTrainingReview.where(id: review.id, status: 'processing', processing_token: token)
    begin
      snapshot!(review, owned)
      if review.attempts >= MAX_ATTEMPTS
        owned.update_all(status: 'failed', error_message: 'review_attempts_exhausted', processing_token: nil, updated_at: Time.current)
        return
      end
      owned.update_all('attempts = attempts + 1')
      review.reload
      return unless review.processing_token == token && review.processing?

      result = Ai::WeeklyReviewAnalyser.new(review).call
      owned.update_all(**result, status: 'completed', processing_token: nil, error_message: nil, retry_at: nil, updated_at: Time.current)
    rescue Ai::Client::TransientError => error
      if review.attempts < MAX_ATTEMPTS
        retry_at = Time.current + (review.attempts**4 + 2).seconds
        updated = owned.update_all(status: 'pending', error_message: error.message, retry_at: retry_at, processing_token: nil, updated_at: Time.current)
        self.class.set(wait_until: retry_at).perform_later(review.id) if updated == 1
      else
        owned.update_all(status: 'failed', error_message: error.message, processing_token: nil, retry_at: nil, updated_at: Time.current)
      end
    rescue StandardError => error
      # If statistics themselves failed, leave preparation recoverable; never send an empty report.
      code = error.is_a?(Ai::Client::Error) || error.is_a?(Ai::InvalidResponse) ? error.message : error.class.name
      owned.update_all(status: review.summary_data ? 'failed' : 'pending', error_message: code,
        processing_token: nil, retry_at: 10.minutes.from_now, updated_at: Time.current)
      Rails.logger.warn("Weekly coaching failed review_id=#{review.id} error_class=#{error.class.name}")
    end
  end

  def snapshot!(review, owned)
    return if review.summary_data && review.input_data

    context_error = nil
    # Both snapshots see the same database state. Commit before contacting OpenAI.
    WeeklyTrainingReview.transaction do
      summary = review.summary_data || WeeklySummaryCalculator.new(user: review.user, week_start: review.week_start.in_time_zone)
        .calculate.as_json.merge('preferred_unit' => review.user.preferred_unit)
      begin
        context = review.input_data || Ai::WeeklyContextBuilder.new(user: review.user, week_start: review.week_start, summary: summary).call
      rescue Ai::InvalidResponse => error
        context_error = error
      end
      updated = owned.update_all(summary_data: summary, input_data: context, updated_at: Time.current)
      raise Ai::InvalidResponse, 'review_superseded' unless updated == 1
    end
    review.reload
    raise context_error if context_error
  end
end
