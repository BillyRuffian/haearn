class SnapshotWeeklyAiRequestSettings < ActiveRecord::Migration[8.1]
  def change
    # Existing reviews keep the request settings used when they were created.
    add_column :weekly_training_reviews, :reasoning_effort, :string
    add_column :weekly_training_reviews, :max_output_tokens, :integer, null: false, default: 6000
    add_column :weekly_training_reviews, :request_timeout, :integer, null: false, default: 90
  end
end
