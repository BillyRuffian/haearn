# frozen_string_literal: true

# Calculates the DOTS relative-strength score for a kilogram total.
class DotsCalculator
  SEXES = %w[male female].freeze
  BODYWEIGHT_RANGES = { 'male' => 40.0..210.0, 'female' => 40.0..150.0 }.freeze
  COEFFICIENTS = {
    'male' => [ -0.0000010930, 0.0007391293, -0.1918759221, 24.0900756, -307.75076 ],
    'female' => [ -0.0000010706, 0.0005158568, -0.1126655495, 13.6175032, -57.96288 ]
  }.freeze

  def initialize(bodyweight_kg:, total_kg:, sex:)
    @bodyweight_kg = bodyweight_kg.to_f
    @total_kg = total_kg.to_f
    @sex = sex.to_s
  end

  def calculate
    return nil unless valid_inputs?

    a, b, c, d, e = COEFFICIENTS.fetch(@sex)
    denominator = (a * @bodyweight_kg**4) + (b * @bodyweight_kg**3) + (c * @bodyweight_kg**2) + (d * @bodyweight_kg) + e
    return nil unless denominator.positive?

    (@total_kg * 500 / denominator).round(2)
  end

  private

  def valid_inputs?
    SEXES.include?(@sex) && BODYWEIGHT_RANGES.fetch(@sex).cover?(@bodyweight_kg) && @total_kg.positive?
  end
end
