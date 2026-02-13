class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notify_readiness, :boolean, default: true, null: false
    add_column :users, :notify_plateau, :boolean, default: true, null: false
    add_column :users, :notify_streak_risk, :boolean, default: true, null: false
    add_column :users, :notify_volume_drop, :boolean, default: true, null: false
    add_column :users, :notify_rest_timer_in_app, :boolean, default: true, null: false
    add_column :users, :notify_rest_timer_push, :boolean, default: true, null: false
  end
end
