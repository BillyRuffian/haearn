# frozen_string_literal: true

# Centralized weight unit conversion service
#
# Core Principle: All weights stored in kg internally, converted for display
#
# Handles three types of conversions:
# 1. Basic unit conversion (kg ↔ lbs)
# 2. Machine display units (what the machine shows vs what you set)
# 3. Machine weight ratios (pulley systems where mechanical advantage affects actual load)
#
# Example: Cable pulley with 2:1 ratio (ratio = 0.5)
# - User selects 100kg on machine
# - Machine displays in lbs (220lbs)
# - Actual weight lifted = 100kg × 0.5 = 50kg (due to pulley)
# - Stored in database as 50kg
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
  # Conversion constants
  KG_TO_LBS = 2.20462  # 1 kg = 2.20462 lbs
  LBS_TO_KG = 1 / KG_TO_LBS  # 1 lb = 0.453592 kg

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
        (kg_value.to_f * KG_TO_LBS).round(2)
      else
        kg_value.to_f.round(2)
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
    #
    # Process:
    # 1. Convert from machine's display unit to kg
    # 2. Apply weight ratio if machine is a cable/pulley system
    #
    # Example: Cable machine with 2:1 pulley, displays in lbs
    # - User selects 220 lbs on machine
    # - Convert to kg: 220 lbs = 100 kg
    # - Apply ratio: 100 kg × 0.5 = 50 kg (actual weight lifted)
    #
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
    # Reverse of machine_to_kg - tells user what to set on machine
    #
    # Process:
    # 1. Reverse the weight ratio (divide instead of multiply)
    # 2. Convert to machine's display unit
    #
    # Example: Want to lift 50kg on 2:1 cable pulley displaying lbs
    # - Reverse ratio: 50 kg / 0.5 = 100 kg
    # - Convert to lbs: 100 kg = 220 lbs
    # - User sets machine to 220 lbs
    #
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
    # Shows up to 2 decimal places, but only if not a whole number
    # @param kg_value [Numeric] weight in kg
    # @param user [User] user for preference
    # @param include_unit [Boolean] whether to append unit suffix
    # @return [String] formatted weight
    def format(kg_value, user:, include_unit: true)
      return '—' if kg_value.nil?

      unit = user&.preferred_unit || 'kg'
      display_value = from_kg(kg_value, unit)
      formatted = format_number(display_value)

      include_unit ? "#{formatted}#{unit}" : formatted
    end

    # Format weight for display without unit suffix
    # Shows up to 2 decimal places, but only if not a whole number
    # @param kg_value [Numeric] weight in kg
    # @param user [User] user for preference
    # @return [String] formatted display value
    def display(kg_value, user:)
      return nil if kg_value.nil?

      unit = user&.preferred_unit || 'kg'
      display_value = from_kg(kg_value, unit)
      format_number(display_value)
    end

    private

    # Format a number showing decimals only when needed
    # Up to 2 decimal places, strips trailing zeros
    # @param value [Numeric] the number to format
    # @return [String] formatted number
    def format_number(value)
      return '0' if value.nil? || value.zero?

      rounded = value.round(2)
      if rounded == rounded.to_i
        rounded.to_i.to_s
      elsif rounded == rounded.round(1)
        Kernel.format('%.1f', rounded)
      else
        Kernel.format('%.2f', rounded)
      end
    end
  end
end
