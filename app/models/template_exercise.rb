# Template exercises define the exercises within a template block
# Stores target sets/reps/weight as guidance when starting workout from template
class TemplateExercise < ApplicationRecord
  belongs_to :template_block
  belongs_to :exercise
  belongs_to :machine, optional: true

  validates :template_block, presence: true
  validates :exercise, presence: true
  validates :target_sets, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :target_reps, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :target_weight_kg, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  delegate :workout_template, to: :template_block
end
