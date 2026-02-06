# frozen_string_literal: true

# Calculates estimated one-rep max (e1RM) from submaximal lifts
# 
# Why?
# Testing your true 1RM is risky and fatiguing. Instead, we estimate it from
# submaximal reps (e.g., 3×225lbs estimates ~245lbs 1RM).
# 
# Multiple Formulas:
# Different formulas work better for different rep ranges:
# - Brzycki: Best for low reps (1-5)
# - Epley: Good all-around, most widely used
# - Lombardi: Simple power formula
# - Mayhew/Wathan: Research-based, complex
# 
# The calculate_average method uses all formulas for better accuracy.
# 
# Used For:
# - Tracking strength progress over time
# - Programming percentages ("work at 80% of 1RM")
# - Comparing performance at different rep ranges
# - Identifying plateau periods
# 
# Note: Estimates become less accurate above 10 reps
class OneRmCalculator
  # Available formulas for 1RM calculation
  # Each has different accuracy for different rep ranges
  FORMULAS = %i[epley brzycki lombardi mayhew oconner wathan].freeze

  # Default formula to use when a single estimate is needed
  # Epley is most widely used and validated
  DEFAULT_FORMULA = :epley

  class << self
    # Calculate estimated 1RM using a specific formula
    # @param weight [Numeric] the weight lifted
    # @param reps [Integer] number of reps completed
    # @param formula [Symbol] which formula to use (default: :epley)
    # @return [Float, nil] estimated 1RM or nil if invalid input
    def calculate(weight, reps, formula: DEFAULT_FORMULA)
      return nil unless valid_input?(weight, reps)
      return weight.to_f if reps == 1

      send("#{formula}_formula", weight.to_f, reps.to_i)
    end

    # Calculate estimated 1RM using multiple formulas and return average
    # More accurate for moderate rep ranges (3-10)
    # For example: 3 reps at 225lbs might give:
    # - Epley: 247lbs
    # - Brzycki: 245lbs
    # - Average: 246lbs (more reliable)
    # 
    # @param weight [Numeric] the weight lifted
    # @param reps [Integer] number of reps completed
    # @return [Float, nil] average estimated 1RM or nil if invalid input
    def calculate_average(weight, reps)
      return nil unless valid_input?(weight, reps)
      return weight.to_f if reps == 1

      estimates = FORMULAS.map { |f| calculate(weight, reps, formula: f) }
      (estimates.sum / estimates.size).round(1)
    end

    # Calculate all formula results for comparison
    # @param weight [Numeric] the weight lifted
    # @param reps [Integer] number of reps completed
    # @return [Hash] hash of formula => estimated 1RM
    def calculate_all(weight, reps)
      return {} unless valid_input?(weight, reps)

      FORMULAS.each_with_object({}) do |formula, hash|
        hash[formula] = calculate(weight, reps, formula: formula)&.round(1)
      end
    end

    # Calculate what weight to use for a target percentage of 1RM
    # Used for programming: "do 3 sets of 5 at 80% of 1RM"
    # 
    # Example: 1RM = 300lbs, target 85%
    # Result: 255lbs
    # 
    # @param one_rm [Numeric] the estimated or known 1RM
    # @param percentage [Numeric] target percentage (e.g., 80 for 80%)
    # @return [Float] weight for that percentage
    def weight_at_percentage(one_rm, percentage)
      return nil unless one_rm.to_f > 0 && percentage.to_f > 0

      (one_rm.to_f * (percentage.to_f / 100)).round(1)
    end

    # Calculate estimated reps possible at a given percentage of 1RM
    # Uses inverse of Epley formula
    # 
    # Example percentages:
    # - 100% = 1 rep
    # - 90% = ~4 reps
    # - 80% = ~8 reps
    # - 70% = ~12 reps
    # 
    # @param percentage [Numeric] percentage of 1RM (e.g., 80 for 80%)
    # @return [Integer] estimated reps possible
    def reps_at_percentage(percentage)
      return nil unless percentage.to_f > 0 && percentage.to_f <= 100

      # Inverse Epley: reps = (100/percentage - 1) * 30
      reps = ((100.0 / percentage.to_f) - 1) * 30
      [ reps.round, 1 ].max
    end

    # Generate a percentage table for training
    # @param one_rm [Numeric] the estimated or known 1RM
    # @return [Array<Hash>] array of {percentage:, weight:, estimated_reps:}
    def percentage_table(one_rm)
      return [] unless one_rm.to_f > 0

      [ 100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50 ].map do |pct|
        {
          percentage: pct,
          weight: weight_at_percentage(one_rm, pct),
          estimated_reps: reps_at_percentage(pct)
        }
      end
    end

    # Find the best estimated 1RM from a collection of sets
    # Useful for finding PRs when sets use different rep ranges
    # 
    # Example sets:
    # - Set 1: 225lbs × 5 = ~254lbs e1RM
    # - Set 2: 245lbs × 3 = ~267lbs e1RM ← best
    # - Set 3: 205lbs × 8 = ~257lbs e1RM
    # 
    # @param sets [Array] array of objects responding to weight_kg and reps
    # @return [Hash, nil] {weight:, reps:, estimated_1rm:, formula:} or nil
    def best_estimated_1rm(sets)
      return nil if sets.blank?

      best = nil
      best_e1rm = 0

      sets.each do |set|
        next unless set.weight_kg.present? && set.reps.present? && set.reps > 0

        e1rm = calculate_average(set.weight_kg, set.reps)
        next unless e1rm && e1rm > best_e1rm

        best_e1rm = e1rm
        best = {
          weight: set.weight_kg,
          reps: set.reps,
          estimated_1rm: e1rm,
          set: set
        }
      end

      best
    end

    private

    # Validate input parameters (prevent invalid calculations)
    # Rejects negative weights, zero reps, or absurdly high reps (>30)
    def valid_input?(weight, reps)
      weight.to_f > 0 && reps.to_i > 0 && reps.to_i <= 30
    end

    # === 1RM Calculation Formulas ===
    # Each formula has different characteristics:

    # Epley Formula: weight × (1 + reps/30)
    # Most widely used, good for moderate rep ranges (3-10)
    # Tends to overestimate at high reps
    def epley_formula(weight, reps)
      (weight * (1 + reps / 30.0)).round(1)
    end

    # Brzycki Formula: weight × (36 / (37 - reps))
    # Slightly more conservative than Epley
    # Best for lower reps (1-5), often used for powerlifting
    # Cannot calculate for 37+ reps
    def brzycki_formula(weight, reps)
      return nil if reps >= 37
      (weight * (36.0 / (37 - reps))).round(1)
    end

    # Lombardi Formula: weight × reps^0.10
    # Simple power formula, conservative
    # Works across all rep ranges but less research backing
    def lombardi_formula(weight, reps)
      (weight * (reps ** 0.10)).round(1)
    end

    # Mayhew Formula: weight / (0.522 + 0.419 × e^(-0.055 × reps))
    # Research-based, uses exponential decay
    # More accurate for high reps (10+)
    def mayhew_formula(weight, reps)
      (weight / (0.522 + 0.419 * Math.exp(-0.055 * reps))).round(1)
    end

    # O'Conner Formula: weight × (1 + 0.025 × reps)
    # Simple linear approximation
    # Conservative, good across all rep ranges
    def oconner_formula(weight, reps)
      (weight * (1 + 0.025 * reps)).round(1)
    end

    # Wathan Formula: weight / (0.4880 + 0.538 × e^(-0.075 × reps))
    # Research-based, similar to Mayhew
    # Another exponential approach with slightly different coefficients
    def wathan_formula(weight, reps)
      (weight / (0.4880 + 0.538 * Math.exp(-0.075 * reps))).round(1)
    end
  end
end
