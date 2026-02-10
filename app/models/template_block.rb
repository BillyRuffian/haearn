# Template blocks mirror workout_blocks structure for reusable workout templates
class TemplateBlock < ApplicationRecord
  belongs_to :workout_template
  has_many :template_exercises, dependent: :destroy

  validates :workout_template, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rest_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  accepts_nested_attributes_for :template_exercises, allow_destroy: true

  scope :ordered, -> { order(:position) }

  # Check if this is a superset (has multiple exercises)
  def superset?
    template_exercises.count > 1
  end
end
