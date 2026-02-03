# frozen_string_literal: true

require "test_helper"

class WeightConverterTest < ActiveSupport::TestCase
  # to_kg tests
  test "to_kg converts lbs to kg" do
    result = WeightConverter.to_kg(100, "lbs")
    assert_in_delta 45.36, result, 0.01
  end

  test "to_kg returns kg unchanged" do
    result = WeightConverter.to_kg(100, "kg")
    assert_equal 100.0, result
  end

  test "to_kg handles nil" do
    assert_nil WeightConverter.to_kg(nil, "lbs")
  end

  test "to_kg defaults to kg" do
    result = WeightConverter.to_kg(50)
    assert_equal 50.0, result
  end

  # from_kg tests
  test "from_kg converts kg to lbs" do
    result = WeightConverter.from_kg(45.36, "lbs")
    assert_in_delta 100.0, result, 0.1
  end

  test "from_kg returns kg unchanged" do
    result = WeightConverter.from_kg(100, "kg")
    assert_equal 100.0, result
  end

  test "from_kg handles nil" do
    assert_nil WeightConverter.from_kg(nil, "lbs")
  end

  # convert tests
  test "convert from lbs to kg" do
    result = WeightConverter.convert(100, from: "lbs", to: "kg")
    assert_in_delta 45.36, result, 0.1
  end

  test "convert from kg to lbs" do
    result = WeightConverter.convert(45.36, from: "kg", to: "lbs")
    assert_in_delta 100.0, result, 0.1
  end

  test "convert same unit returns value" do
    result = WeightConverter.convert(100, from: "kg", to: "kg")
    assert_equal 100.0, result
  end

  # machine_to_kg tests
  test "machine_to_kg with no machine uses kg" do
    result = WeightConverter.machine_to_kg(100, nil)
    assert_equal 100.0, result
  end

  test "machine_to_kg converts machine display unit" do
    machine = Machine.new(display_unit: "lbs")
    result = WeightConverter.machine_to_kg(100, machine)
    assert_in_delta 45.36, result, 0.01
  end

  test "machine_to_kg applies weight ratio for cables" do
    machine = Machine.new(display_unit: "kg", weight_ratio: 0.5, equipment_type: "cables")
    result = WeightConverter.machine_to_kg(100, machine)
    assert_equal 50.0, result
  end

  test "machine_to_kg combines unit conversion and ratio" do
    # Machine shows lbs with 2:1 ratio (0.5)
    machine = Machine.new(display_unit: "lbs", weight_ratio: 0.5, equipment_type: "cables")
    result = WeightConverter.machine_to_kg(100, machine)
    # 100 lbs = 45.36 kg, then * 0.5 = 22.68 kg
    assert_in_delta 22.68, result, 0.01
  end

  # kg_to_machine tests
  test "kg_to_machine with no machine uses kg" do
    result = WeightConverter.kg_to_machine(100, nil)
    assert_equal 100.0, result
  end

  test "kg_to_machine converts to machine display unit" do
    machine = Machine.new(display_unit: "lbs")
    result = WeightConverter.kg_to_machine(45.36, machine)
    assert_in_delta 100.0, result, 0.1
  end

  test "kg_to_machine reverses weight ratio" do
    machine = Machine.new(display_unit: "kg", weight_ratio: 0.5, equipment_type: "cables")
    result = WeightConverter.kg_to_machine(50, machine)
    assert_equal 100.0, result
  end

  # format tests
  test "format returns formatted string with unit" do
    user = User.new(preferred_unit: "kg")
    result = WeightConverter.format(100, user: user)
    assert_equal "100kg", result
  end

  test "format converts to user preference" do
    user = User.new(preferred_unit: "lbs")
    result = WeightConverter.format(45.36, user: user)
    assert_equal "100lbs", result
  end

  test "format handles nil" do
    user = User.new(preferred_unit: "kg")
    result = WeightConverter.format(nil, user: user)
    assert_equal "—", result
  end

  test "format with precision" do
    user = User.new(preferred_unit: "kg")
    result = WeightConverter.format(100.567, user: user, precision: 1)
    assert_equal "100.6kg", result
  end

  # display tests
  test "display returns numeric value" do
    user = User.new(preferred_unit: "lbs")
    result = WeightConverter.display(45.36, user: user)
    assert_in_delta 100.0, result, 0.1
  end

  test "display handles nil" do
    user = User.new(preferred_unit: "kg")
    assert_nil WeightConverter.display(nil, user: user)
  end
end
