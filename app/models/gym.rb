class Gym < ApplicationRecord
  belongs_to :user
  has_many :machines, dependent: :destroy
  has_many :workouts, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
