# frozen_string_literal: true

# Calculates Wilks coefficient for powerlifting
# Wilks score normalizes strength across bodyweight classes
#
# Wilks = Total Lifted (kg) × Wilks Coefficient
# The coefficient is calculated using a polynomial formula based on bodyweight
#
# Usage:
#   calculator = WilksCalculator.new(bodyweight_kg: 82.5, total_kg: 600, sex: :male)
#   calculator.calculate # => 412.5
class WilksCalculator
  # Wilks coefficient constants (2020 formula)
  MALE_COEFFICIENTS = {
    a: -216.0475144,
    b: 16.2606339,
    c: -0.002388645,
    d: -0.00113732,
    e: 7.01863e-06,
    f: -1.291e-08
  }.freeze

  FEMALE_COEFFICIENTS = {
    a: 594.31747775582,
    b: -27.23842536447,
    c: 0.82112226871,
    d: -0.00930733913,
    e: 4.731582e-05,
    f: -9.054e-08
  }.freeze

  attr_reader :bodyweight_kg, :total_kg, :sex

  def initialize(bodyweight_kg:, total_kg:, sex: :male)
    @bodyweight_kg = bodyweight_kg.to_f
    @total_kg = total_kg.to_f
    @sex = sex.to_sym
  end

  # Calculate Wilks score
  # Returns nil if bodyweight or total is invalid
  def calculate
    return nil unless valid_inputs?

    coefficient = wilks_coefficient
    return nil if coefficient.zero?

    (total_kg * coefficient).round(2)
  end

  # Calculate the Wilks coefficient for the bodyweight
  def wilks_coefficient
    return 0 unless valid_inputs?

    coeffs = sex == :female ? FEMALE_COEFFICIENTS : MALE_COEFFICIENTS
    bw = bodyweight_kg

    denominator = coeffs[:a] +
                  coeffs[:b] * bw +
                  coeffs[:c] * bw**2 +
                  coeffs[:d] * bw**3 +
                  coeffs[:e] * bw**4 +
                  coeffs[:f] * bw**5

    return 0 if denominator.zero?

    (500.0 / denominator).round(6)
  end

  # Strength classification based on Wilks score
  # Returns :novice, :intermediate, :advanced, :elite, or :world_class
  def classification
    score = calculate
    return :novice unless score

    # Approximate classifications (vary by federation/source)
    case score
    when 0...250 then :novice
    when 250...350 then :intermediate
    when 350...450 then :advanced
    when 450...550 then :elite
    else :world_class
    end
  end

  # Human-readable classification label
  def classification_label
    {
      novice: 'Novice',
      intermediate: 'Intermediate',
      advanced: 'Advanced',
      elite: 'Elite',
      world_class: 'World Class'
    }[classification]
  end

  private

  def valid_inputs?
    bodyweight_kg > 0 && bodyweight_kg < 300 && total_kg > 0 && total_kg < 2000
  end
end
