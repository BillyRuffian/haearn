# == Schema Information
#
# Table name: workout_templates
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  pinned      :boolean          default(FALSE)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
# Indexes
#
#  index_workout_templates_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class WorkoutTemplate < ApplicationRecord
  belongs_to :user
  has_many :template_blocks, dependent: :destroy
  has_many :template_exercises, through: :template_blocks

  validates :name, presence: true
  validates :user, presence: true

  accepts_nested_attributes_for :template_blocks, allow_destroy: true

  scope :ordered, -> { order(name: :asc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pinned, -> { where(pinned: true) }

  def pinned?
    pinned == true
  end

  def toggle_pin!
    update!(pinned: !pinned?)
  end
end
