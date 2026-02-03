# frozen_string_literal: true

# WeightConverter handles all weight unit conversions in the app.
# Internally, all weights are stored in kilograms (kg).
#
# Usage:
#   WeightConverter.to_kg(100, "lbs")  # => 45.36
#   WeightConverter.from_kg(45.36, "lbs")  # => 100.0
#   WeightConverter.convert(100, from: "lbs", to: "kg")  # => 45.36
#
# With machine weight ratios (for cable pulleys):
#   WeightConverter.machine_to_kg(100, machine)  # applies ratio and unit conversion
#   WeightConverter.kg_to_machine(45.36, machine)  # reverse conversion
#
class WeightConverter
  KG_TO_LBS = 2.20462
  LBS_TO_KG = 1 / KG_TO_LBS

  class << self
    # Convert a value to kilograms
    # @param value [Numeric] the weight value
    # @param from_unit [String] "kg" or "lbs"
    # @return [Float, nil] weight in kg
    def to_kg(value, from_unit = 'kg')
      return nil if value.nil?

      case from_unit.to_s.downcase
      when 'lbs'
        (value.to_f * LBS_TO_KG).round(2)
      else
        value.to_f.round(2)
      end
    end

    # Convert a value from kilograms to another unit
    # @param kg_value [Numeric] the weight in kg
    # @param to_unit [String] "kg" or "lbs"
    # @return [Float, nil] weight in target unit
    def from_kg(kg_value, to_unit = 'kg')
      return nil if kg_value.nil?

      case to_unit.to_s.downcase
      when 'lbs'
        (kg_value.to_f * KG_TO_LBS).round(1)
      else
        kg_value.to_f.round(1)
      end
    end

    # Convert between any two units
    # @param value [Numeric] the weight value
    # @param from [String] source unit
    # @param to [String] target unit
    # @return [Float, nil] converted weight
    def convert(value, from:, to:)
      return nil if value.nil?
      return value.to_f.round(2) if from == to

      kg_value = to_kg(value, from)
      from_kg(kg_value, to)
    end

    # Convert machine-displayed weight to kg for storage
    # Handles both display_unit and weight_ratio (for cables)
    # @param displayed_value [Numeric] weight shown on machine
    # @param machine [Machine] the machine record
    # @return [Float, nil] actual weight being lifted in kg
    def machine_to_kg(displayed_value, machine)
      return nil if displayed_value.nil?
      return to_kg(displayed_value, 'kg') if machine.nil?

      # First convert from machine's display unit to kg
      unit = machine.display_unit || 'kg'
      kg_value = to_kg(displayed_value, unit)

      # Then apply weight ratio for cables
      if machine.weight_ratio.present?
        kg_value = (kg_value * machine.weight_ratio).round(2)
      end

      kg_value
    end

    # Convert kg to machine display weight
    # Reverse of machine_to_kg
    # @param kg_value [Numeric] actual weight in kg
    # @param machine [Machine] the machine record
    # @return [Float, nil] weight to set on machine
    def kg_to_machine(kg_value, machine)
      return nil if kg_value.nil?
      return from_kg(kg_value, 'kg') if machine.nil?

      # First reverse the weight ratio
      value = kg_value.to_f
      if machine.weight_ratio.present? && machine.weight_ratio > 0
        value = value / machine.weight_ratio
      end

      # Then convert to machine's display unit
      unit = machine.display_unit || 'kg'
      from_kg(value, unit)
    end

    # Format weight for display with unit suffix
    # @param kg_value [Numeric] weight in kg
    # @param user [User] user for preference
    # @param precision [Integer] decimal places
    # @return [String] formatted weight with unit
    def format(kg_value, user:, precision: 0)
      return '—' if kg_value.nil?

      unit = user&.preferred_unit || 'kg'
      display_value = from_kg(kg_value, unit)

      if precision > 0
        "#{display_value.round(precision)}#{unit}"
      else
        "#{display_value.round}#{unit}"
      end
    end

    # Format weight for display without unit suffix
    # @param kg_value [Numeric] weight in kg
    # @param user [User] user for preference
    # @return [Numeric] display value
    def display(kg_value, user:)
      return nil if kg_value.nil?

      unit = user&.preferred_unit || 'kg'
      from_kg(kg_value, unit)
    end
  end
end
