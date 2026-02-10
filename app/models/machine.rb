# == Schema Information
#
# Table name: machines
#
#  id             :integer          not null, primary key
#  display_unit   :string
#  equipment_type :string
#  name           :string
#  notes          :text
#  weight_ratio   :decimal(, )
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  gym_id         :integer          not null
#
# Indexes
#
#  index_machines_on_gym_id  (gym_id)
#
# Foreign Keys
#
#  gym_id  (gym_id => gyms.id)
#
# Represents specific equipment at a gym (e.g., "Hammer Strength Chest Press")
#
# Critical Features:
# - weight_ratio: For pulley systems where mechanical advantage affects actual weight
#   Example: 2:1 cable pulley has ratio 0.5 (you lift half the displayed weight)
# - display_unit: What unit the machine shows (kg or lbs)
# - photos: Visual reference for proper setup (seat position, grip, etc.)
#
# Why track individual machines?
# - Same exercise on different machines = different resistance curves
# - Cable machines have different pulley ratios (2:1, 1:1, etc.)
# - Progress tracking needs to be machine-specific for accurate PRs
# - Photos help remember setup ("seat at position 4, neutral grip")
class Machine < ApplicationRecord
  belongs_to :gym
  has_many :workout_exercises, dependent: :nullify
  has_many_attached :photos

  # Available equipment types
  EQUIPMENT_TYPES = %w[
    barbell
    dumbbell
    machine
    cables
    bodyweight
    kettlebell
    bands
    smith_machine
    other
  ].freeze

  UNITS = %w[kg lbs].freeze

  validates :name, presence: true
  validates :equipment_type, presence: true, inclusion: { in: EQUIPMENT_TYPES }
  validates :weight_ratio, numericality: { greater_than: 0 }, allow_nil: true
  validates :display_unit, inclusion: { in: UNITS }, allow_nil: true
  validate :acceptable_photos

  scope :ordered, -> { order(:name) }

  # Calculate the actual weight lifted for cable/pulley machines
  # For cable machines: actual weight = displayed weight × ratio
  # Example: 100kg stack with 2:1 pulley (ratio=0.5) = 50kg actual
  # @param displayed_weight [Numeric] weight shown on machine
  # @return [Numeric] actual weight being lifted
  def effective_weight(displayed_weight)
    return displayed_weight if weight_ratio.nil?
    displayed_weight * weight_ratio
  end

  def cables?
    equipment_type == 'cables'
  end

  def barbell?
    equipment_type == 'barbell'
  end

  def smith_machine?
    equipment_type == 'smith_machine'
  end

  # Check if this equipment uses plate loading (vs fixed weight stack)
  # Useful for calculating available weights based on plate inventory
  def plate_loaded?
    barbell? || smith_machine?
  end

  private

  def acceptable_photos
    return unless photos.attached?

    photos.each do |photo|
      unless photo.blob.content_type.in?(%w[image/jpeg image/png image/webp image/heic image/heif])
        errors.add(:photos, 'must be JPEG, PNG, WebP, or HEIC')
      end

      if photo.blob.byte_size > 10.megabytes
        errors.add(:photos, 'must be less than 10MB each')
      end
    end
  end
end
