# Template blocks mirror workout_blocks structure for reusable workout templates
# == Schema Information
#
# Table name: template_blocks
#
#  id                  :integer          not null, primary key
#  position            :integer          default(0), not null
#  removed_at          :datetime
#  rest_seconds        :integer          default(90)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  workout_template_id :integer          not null
#
# Indexes
#
#  index_template_blocks_on_workout_template_id                 (workout_template_id)
#  index_template_blocks_on_workout_template_id_and_position    (workout_template_id,position)
#  index_template_blocks_on_workout_template_id_and_removed_at  (workout_template_id,removed_at)
#
# Foreign Keys
#
#  workout_template_id  (workout_template_id => workout_templates.id)
#
class TemplateBlock < ApplicationRecord
  belongs_to :workout_template
  has_many :all_template_exercises, class_name: 'TemplateExercise', dependent: :destroy
  has_many :template_exercises, -> { active }, class_name: 'TemplateExercise'

  validates :workout_template, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rest_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  accepts_nested_attributes_for :template_exercises, allow_destroy: true

  scope :ordered, -> { order(:position) }
  scope :active, -> { where(removed_at: nil) }

  # Keep the block and its exercise IDs available to historical workouts.
  def remove_from_template!
    with_lock do
      removed_at = Time.current
      template_exercises.update_all(removed_at: removed_at, updated_at: removed_at)
      update!(removed_at: removed_at)
    end
  end

  # Check if this is a superset (has multiple exercises)
  def superset?
    template_exercises.count > 1
  end
end
