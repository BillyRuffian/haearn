# == Schema Information
#
# Table name: gyms
#
#  id         :integer          not null, primary key
#  location   :string
#  name       :string
#  notes      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_gyms_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class Gym < ApplicationRecord
  belongs_to :user
  has_many :machines, dependent: :destroy
  has_many :workouts, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
