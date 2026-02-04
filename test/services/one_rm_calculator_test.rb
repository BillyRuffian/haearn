# frozen_string_literal: true

require "test_helper"
require "ostruct"

class OneRmCalculatorTest < ActiveSupport::TestCase
  # Test basic functionality
  test "returns nil for invalid weight" do
    assert_nil OneRmCalculator.calculate(0, 5)
    assert_nil OneRmCalculator.calculate(-100, 5)
    assert_nil OneRmCalculator.calculate(nil, 5)
  end

  test "returns nil for invalid reps" do
    assert_nil OneRmCalculator.calculate(100, 0)
    assert_nil OneRmCalculator.calculate(100, -1)
    assert_nil OneRmCalculator.calculate(100, 31) # > 30 is invalid
    assert_nil OneRmCalculator.calculate(100, nil)
  end

  test "returns weight for 1 rep" do
    assert_equal 100.0, OneRmCalculator.calculate(100, 1)
    assert_equal 225.0, OneRmCalculator.calculate(225, 1)
  end

  # Test individual formulas with known values
  # Using 100kg x 10 reps as baseline

  test "epley formula calculates correctly" do
    # Epley: weight × (1 + reps/30) = 100 × (1 + 10/30) = 100 × 1.333 = 133.3
    result = OneRmCalculator.calculate(100, 10, formula: :epley)
    assert_in_delta 133.3, result, 0.1
  end

  test "brzycki formula calculates correctly" do
    # Brzycki: weight × (36 / (37 - reps)) = 100 × (36 / 27) = 133.3
    result = OneRmCalculator.calculate(100, 10, formula: :brzycki)
    assert_in_delta 133.3, result, 0.1
  end

  test "lombardi formula calculates correctly" do
    # Lombardi: weight × reps^0.10 = 100 × 10^0.10 = 100 × 1.259 = 125.9
    result = OneRmCalculator.calculate(100, 10, formula: :lombardi)
    assert_in_delta 125.9, result, 0.1
  end

  test "oconner formula calculates correctly" do
    # O'Conner: weight × (1 + 0.025 × reps) = 100 × 1.25 = 125
    result = OneRmCalculator.calculate(100, 10, formula: :oconner)
    assert_in_delta 125.0, result, 0.1
  end

  # Test average calculation
  test "calculate_average returns average of all formulas" do
    result = OneRmCalculator.calculate_average(100, 10)
    assert_not_nil result
    
    # Should be between the lowest (O'Conner/Lombardi ~125) and highest (Epley/Brzycki ~133)
    assert result > 125, "Average should be greater than 125"
    assert result < 140, "Average should be less than 140"
  end

  test "calculate_average returns weight for 1 rep" do
    assert_equal 100.0, OneRmCalculator.calculate_average(100, 1)
  end

  # Test calculate_all
  test "calculate_all returns hash of all formulas" do
    results = OneRmCalculator.calculate_all(100, 10)
    
    assert_kind_of Hash, results
    assert_equal 6, results.size
    
    OneRmCalculator::FORMULAS.each do |formula|
      assert results.key?(formula), "Missing formula: #{formula}"
      assert_not_nil results[formula]
    end
  end

  # Test percentage calculations
  test "weight_at_percentage calculates correctly" do
    assert_equal 80.0, OneRmCalculator.weight_at_percentage(100, 80)
    assert_equal 95.0, OneRmCalculator.weight_at_percentage(100, 95)
    assert_equal 50.0, OneRmCalculator.weight_at_percentage(100, 50)
  end

  test "weight_at_percentage returns nil for invalid inputs" do
    assert_nil OneRmCalculator.weight_at_percentage(0, 80)
    assert_nil OneRmCalculator.weight_at_percentage(100, 0)
    assert_nil OneRmCalculator.weight_at_percentage(-100, 80)
  end

  test "reps_at_percentage returns reasonable values" do
    # At 100%, should be 1 rep
    assert_equal 1, OneRmCalculator.reps_at_percentage(100)
    
    # At lower percentages, more reps possible
    reps_at_80 = OneRmCalculator.reps_at_percentage(80)
    reps_at_70 = OneRmCalculator.reps_at_percentage(70)
    
    assert reps_at_80 > 1, "Should be able to do more than 1 rep at 80%"
    assert reps_at_70 > reps_at_80, "Should do more reps at 70% than 80%"
  end

  test "reps_at_percentage returns nil for invalid percentages" do
    assert_nil OneRmCalculator.reps_at_percentage(0)
    assert_nil OneRmCalculator.reps_at_percentage(-50)
    assert_nil OneRmCalculator.reps_at_percentage(101)
  end

  # Test percentage table
  test "percentage_table returns correct structure" do
    table = OneRmCalculator.percentage_table(100)
    
    assert_kind_of Array, table
    assert_equal 11, table.size # 100, 95, 90... 50
    
    first = table.first
    assert_equal 100, first[:percentage]
    assert_equal 100.0, first[:weight]
    assert_equal 1, first[:estimated_reps]
    
    last = table.last
    assert_equal 50, last[:percentage]
    assert_equal 50.0, last[:weight]
  end

  test "percentage_table returns empty array for invalid 1rm" do
    assert_equal [], OneRmCalculator.percentage_table(0)
    assert_equal [], OneRmCalculator.percentage_table(-100)
  end

  # Test best_estimated_1rm with mock sets
  test "best_estimated_1rm finds highest e1rm from sets" do
    # Create mock sets with weight_kg and reps
    sets = [
      OpenStruct.new(weight_kg: 100, reps: 5),   # e1RM ≈ 116.7
      OpenStruct.new(weight_kg: 80, reps: 10),   # e1RM ≈ 106.7
      OpenStruct.new(weight_kg: 120, reps: 1)    # e1RM = 120 (highest)
    ]
    
    result = OneRmCalculator.best_estimated_1rm(sets)
    
    assert_not_nil result
    assert_equal 120, result[:weight]
    assert_equal 1, result[:reps]
    assert_equal 120.0, result[:estimated_1rm]
  end

  test "best_estimated_1rm returns nil for empty sets" do
    assert_nil OneRmCalculator.best_estimated_1rm([])
    assert_nil OneRmCalculator.best_estimated_1rm(nil)
  end

  test "best_estimated_1rm skips sets without weight or reps" do
    sets = [
      OpenStruct.new(weight_kg: nil, reps: 10),
      OpenStruct.new(weight_kg: 100, reps: nil),
      OpenStruct.new(weight_kg: 100, reps: 0),
      OpenStruct.new(weight_kg: 80, reps: 10)    # Only valid set
    ]
    
    result = OneRmCalculator.best_estimated_1rm(sets)
    
    assert_not_nil result
    assert_equal 80, result[:weight]
    assert_equal 10, result[:reps]
  end

  # Test real-world scenarios
  test "common bench press scenario - 225lbs x 5" do
    # 225 x 5 should give roughly 253-261 lbs estimated 1RM
    result = OneRmCalculator.calculate_average(225, 5)
    assert result > 250, "225x5 should estimate 1RM over 250"
    assert result < 270, "225x5 should estimate 1RM under 270"
  end

  test "common squat scenario - 315lbs x 3" do
    # 315 x 3 should give roughly 335-345 lbs estimated 1RM
    result = OneRmCalculator.calculate_average(315, 3)
    assert result > 330, "315x3 should estimate 1RM over 330"
    assert result < 350, "315x3 should estimate 1RM under 350"
  end
end
