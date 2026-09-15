class IndexAiReviewsForCostReporting < ActiveRecord::Migration[8.1]
  def change
    add_index :workout_analyses, :created_at
    add_index :weekly_training_reviews, :created_at
  end
end
