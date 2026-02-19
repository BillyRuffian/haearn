class AddLastSuccessfulPushAtToPushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :push_subscriptions, :last_successful_push_at, :datetime
    add_index :push_subscriptions, :last_successful_push_at
  end
end
