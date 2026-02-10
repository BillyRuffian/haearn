# Template exercises define the exercises within a template block
# Stores target sets/reps/weight as guidance when starting workout from template
# == Schema Information
#
# Table name: template_exercises
#
#  id                :integer          not null, primary key
#  persistent_notes  :text
#  target_reps       :integer
#  target_sets       :integer
#  target_weight_kg  :decimal(8, 2)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  exercise_id       :integer          not null
#  machine_id        :integer
#  template_block_id :integer          not null
#
# Indexes
#
#  index_template_exercises_on_exercise_id                        (exercise_id)
#  index_template_exercises_on_machine_id                         (machine_id)
#  index_template_exercises_on_template_block_id                  (template_block_id)
#  index_template_exercises_on_template_block_id_and_exercise_id  (template_block_id,exercise_id)
#
# Foreign Keys
#
#  exercise_id        (exercise_id => exercises.id)
#  machine_id         (machine_id => machines.id)
#  template_block_id  (template_block_id => template_blocks.id)
#
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
