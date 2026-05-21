require 'test_helper'

class MachinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @gym = gyms(:one)
    sign_in_as(@user)
  end

  test 'gym page preselects user preferred unit for new machine form' do
    get gym_path(@gym)
    assert_response :success

    assert_select "select[name='machine[display_unit]'] option[selected][value='kg']"
  end

  test 'create defaults blank display_unit to user preferred unit' do
    assert_difference('Machine.count', 1) do
      post gym_machines_path(@gym), params: {
        machine: {
          name: 'Test Machine Default Unit',
          equipment_type: 'machine',
          display_unit: ''
        }
      }
    end

    machine = Machine.order(:id).last
    assert_equal 'kg', machine.display_unit
  end

  test 'create keeps explicit display_unit override' do
    assert_difference('Machine.count', 1) do
      post gym_machines_path(@gym), params: {
        machine: {
          name: 'Test Machine Explicit Unit',
          equipment_type: 'machine',
          display_unit: 'lbs'
        }
      }
    end

    machine = Machine.order(:id).last
    assert_equal 'lbs', machine.display_unit
  end

  test 'new machine page includes display unit selector and no weight increment field' do
    get new_gym_machine_path(@gym)
    assert_response :success

    assert_select "select[name='machine[display_unit]']"
    assert_select "input[name='machine[weight_increment]']", count: 0
  end

  test 'retire marks machine unavailable without deleting it' do
    machine = @gym.machines.create!(name: 'Retirable Rig', equipment_type: 'machine', display_unit: 'kg')

    assert_no_difference('Machine.count') do
      patch retire_gym_machine_path(@gym, machine)
    end

    assert_redirected_to gym_path(@gym)
    assert machine.reload.retired?
  end

  test 'reactivate makes a retired machine available again' do
    machine = @gym.machines.create!(name: 'Reactivatable Rig', equipment_type: 'machine', display_unit: 'kg', retired_at: Time.current)

    patch reactivate_gym_machine_path(@gym, machine)

    assert_redirected_to gym_path(@gym)
    assert machine.reload.active?
  end

  test 'gym page separates active and retired equipment' do
    @gym.machines.create!(name: 'Active Rig', equipment_type: 'machine', display_unit: 'kg')
    @gym.machines.create!(name: 'Retired Rig', equipment_type: 'machine', display_unit: 'kg', retired_at: Time.current)

    get gym_path(@gym)
    assert_response :success

    assert_select '#machines', text: /Active Rig/
    assert_select '#machines', text: /Retired Rig/, count: 0
    assert_select '#retired_machines', text: /Retired Rig/
    assert_select 'span.badge', text: 'Retired'
  end
end
