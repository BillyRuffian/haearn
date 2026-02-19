# == Schema Information
#
# Table name: push_subscriptions
#
#  id                      :integer          not null, primary key
#  auth_key                :string           not null
#  endpoint                :text             not null
#  expiration_time         :datetime
#  last_successful_push_at :datetime
#  p256dh_key              :string           not null
#  user_agent              :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :integer          not null
#
# Indexes
#
#  index_push_subscriptions_on_endpoint                 (endpoint) UNIQUE
#  index_push_subscriptions_on_last_successful_push_at  (last_successful_push_at)
#  index_push_subscriptions_on_user_id                  (user_id)
#  index_push_subscriptions_on_user_id_and_endpoint     (user_id,endpoint) UNIQUE
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true
  validates :endpoint, uniqueness: true

  scope :with_successful_push, -> { where.not(last_successful_push_at: nil) }

  def self.health_for_user(user)
    relation = where(user_id: user.id)
    {
      subscribed_device_count: relation.count,
      last_successful_push_at: relation.maximum(:last_successful_push_at)
    }
  end
end
