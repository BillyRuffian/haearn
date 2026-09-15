class RecoverWeeklyTrainingReviewsJob < ApplicationJob
  queue_as :default

  def perform
    WeeklyTrainingReview.where(delivery_status: 'sending', delivery_started_at: ..Ai::Config.processing_lease.ago)
      .update_all(delivery_status: 'uncertain', delivery_error: 'delivery_interrupted', processing_token: nil, updated_at: Time.current)
    WeeklyTrainingReview.recoverable.find_each do |review|
      next if review.processing? && review.updated_at > Ai::Config.processing_lease.ago

      WeeklyTrainingReviewJob.perform_later(review.id)
    end
  end
end
