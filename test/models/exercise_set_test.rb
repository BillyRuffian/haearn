# == Schema Information
#
# Table name: exercise_sets
#
#  id                  :integer          not null, primary key
#  band_tension_kg     :decimal(, )
#  belt                :boolean          default(FALSE), not null
#  chain_weight_kg     :decimal(, )
#  completed_at        :datetime
#  distance_meters     :decimal(, )
#  duration_seconds    :integer
#  is_amrap            :boolean          default(FALSE)
#  is_bfr              :boolean          default(FALSE), not null
#  is_failed           :boolean          default(FALSE), not null
#  is_warmup           :boolean
#  knee_sleeves        :boolean          default(FALSE), not null
#  pain_flag           :boolean          default(FALSE), not null
#  pain_note           :string
#  partial_reps        :integer
#  position            :integer
#  reps                :integer
#  rir                 :integer
#  rpe                 :decimal(, )
#  set_type            :string           default("normal")
#  spotter_assisted    :boolean          default(FALSE), not null
#  straps              :boolean          default(FALSE), not null
#  tempo_concentric    :integer
#  tempo_eccentric     :integer
#  tempo_pause_bottom  :integer
#  tempo_pause_top     :integer
#  weight_kg           :decimal(, )
#  wrist_wraps         :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  workout_exercise_id :integer          not null
#
# Indexes
#
#  index_exercise_sets_on_workout_exercise_id  (workout_exercise_id)
#
# Foreign Keys
#
#  workout_exercise_id  (workout_exercise_id => workout_exercises.id)
#
require 'test_helper'

class ExerciseSetTest < ActiveSupport::TestCase
  setup do
    DashboardAnalyticsCache.reset_invalidation_tracking!
    @set = exercise_sets(:one)
  end

  teardown do
    DashboardAnalyticsCache.reset_invalidation_tracking!
  end

  test 'invalidates dashboard analytics cache after commit' do
    @set.update!(reps: @set.reps + 1)

    tokens = DashboardAnalyticsCache.invalidation_tokens
    assert_includes tokens, DashboardAnalyticsCache.invalidation_token(user_id: @set.workout.user_id, key: 'plateaus')
  end

  test 'does not invalidate dashboard analytics cache for non-analytics update' do
    @set.update!(pain_note: 'minor discomfort')

    tokens = DashboardAnalyticsCache.invalidation_tokens
    assert_not_includes tokens, DashboardAnalyticsCache.invalidation_token(user_id: @set.workout.user_id, key: 'plateaus')
  end

  def create_pr_scope_candidate(previous_weight:, current_weight:, equipped: false)
    user = users(:one)
    gym = gyms(:one)
    exercise = exercises(:one)
    machine = machines(:one)

    previous_workout = Workout.create!(
      user: user,
      gym: gym,
      started_at: 7.days.ago,
      finished_at: 7.days.ago + 1.hour
    )
    previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    previous_we = previous_block.workout_exercises.create!(
      exercise: exercise,
      machine: machine,
      position: 1
    )
    previous_we.exercise_sets.create!(
      weight_kg: previous_weight,
      reps: 5,
      position: 1,
      is_warmup: false,
      belt: equipped
    )

    current_workout = Workout.create!(
      user: user,
      gym: gym,
      started_at: Time.current,
      finished_at: nil
    )
    current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    current_we = current_block.workout_exercises.create!(
      exercise: exercise,
      machine: machine,
      position: 1
    )
    current_we.exercise_sets.create!(
      weight_kg: current_weight,
      reps: 5,
      position: 1,
      is_warmup: false,
      belt: equipped
    )
  end

  # --- Set Type Validations ---

  test 'default set_type is normal' do
    assert_equal 'normal', ExerciseSet.new.set_type
  end

  test 'valid set types accepted' do
    ExerciseSet::SET_TYPES.each do |type|
      @set.set_type = type
      assert @set.valid?, "Expected set_type '#{type}' to be valid"
    end
  end

  test 'invalid set type rejected' do
    @set.set_type = 'invalid_type'
    assert_not @set.valid?
    assert_includes @set.errors[:set_type], 'is not included in the list'
  end

  # --- Set Type Helpers ---

  test 'set type predicates' do
    @set.set_type = 'normal'
    assert @set.normal?
    assert_not @set.advanced_set_type?

    @set.set_type = 'drop_set'
    assert @set.drop_set?
    assert @set.advanced_set_type?

    @set.set_type = 'rest_pause'
    assert @set.rest_pause?

    @set.set_type = 'cluster'
    assert @set.cluster?

    @set.set_type = 'myo_rep'
    assert @set.myo_rep?

    @set.set_type = 'backoff'
    assert @set.backoff?
  end

  test 'set_type_label returns human-readable labels' do
    @set.set_type = 'drop_set'
    assert_equal 'Drop Set', @set.set_type_label

    @set.set_type = 'rest_pause'
    assert_equal 'Rest-Pause', @set.set_type_label

    @set.set_type = 'normal'
    assert_equal 'Normal', @set.set_type_label
  end

  test 'set_type_badge returns short codes' do
    @set.set_type = 'drop_set'
    assert_equal 'D', @set.set_type_badge

    @set.set_type = 'rest_pause'
    assert_equal 'RP', @set.set_type_badge

    @set.set_type = 'normal'
    assert_nil @set.set_type_badge
  end

  test 'set_type_color returns Bootstrap color class' do
    @set.set_type = 'drop_set'
    assert_equal 'danger', @set.set_type_color

    @set.set_type = 'myo_rep'
    assert_equal 'success', @set.set_type_color
  end

  # --- Tempo Validations ---

  test 'tempo fields accept valid values' do
    @set.tempo_eccentric = 3
    @set.tempo_pause_bottom = 1
    @set.tempo_concentric = 2
    @set.tempo_pause_top = 0
    assert @set.valid?
  end

  test 'tempo fields reject values below 0' do
    @set.tempo_eccentric = -1
    assert_not @set.valid?
    assert_includes @set.errors[:tempo_eccentric], 'must be greater than or equal to 0'
  end

  test 'tempo fields reject values above 30' do
    @set.tempo_concentric = 31
    assert_not @set.valid?
    assert_includes @set.errors[:tempo_concentric], 'must be less than or equal to 30'
  end

  test 'tempo fields accept nil' do
    @set.tempo_eccentric = nil
    @set.tempo_pause_bottom = nil
    @set.tempo_concentric = nil
    @set.tempo_pause_top = nil
    assert @set.valid?
  end

  # --- Tempo Helpers ---

  test 'has_tempo? returns true when any tempo field set' do
    @set.tempo_eccentric = 3
    assert @set.has_tempo?
  end

  test 'has_tempo? returns false when no tempo fields set' do
    @set.tempo_eccentric = nil
    @set.tempo_pause_bottom = nil
    @set.tempo_concentric = nil
    @set.tempo_pause_top = nil
    assert_not @set.has_tempo?
  end

  test 'tempo_display formats as dash-separated string' do
    @set.tempo_eccentric = 3
    @set.tempo_pause_bottom = 1
    @set.tempo_concentric = 2
    @set.tempo_pause_top = 0
    assert_equal '3-1-2-0', @set.tempo_display
  end

  test 'tempo_display returns nil when no tempo' do
    assert_nil @set.tempo_display
  end

  test 'tempo_tut calculates total time under tension' do
    @set.tempo_eccentric = 3
    @set.tempo_pause_bottom = 1
    @set.tempo_concentric = 2
    @set.tempo_pause_top = 0
    assert_equal 6, @set.tempo_tut
  end

  test 'tempo_tut returns nil when no tempo' do
    assert_nil @set.tempo_tut
  end

  # --- Scope ---

  test 'by_type scope filters correctly' do
    @set.update!(set_type: 'drop_set')
    results = ExerciseSet.by_type('drop_set')
    assert_includes results, @set
  end

  # --- Equipment ---

  test 'equipped? returns false when no equipment' do
    assert_not @set.equipped?
  end

  test 'equipped? returns true when belt is on' do
    @set.belt = true
    assert @set.equipped?
  end

  test 'equipped? returns true when any equipment is on' do
    @set.knee_sleeves = true
    assert @set.equipped?

    @set.knee_sleeves = false
    @set.wrist_wraps = true
    assert @set.equipped?

    @set.wrist_wraps = false
    @set.straps = true
    assert @set.equipped?
  end

  test 'equipment_list returns array of equipped items' do
    @set.belt = true
    @set.straps = true
    list = @set.equipment_list
    assert_includes list, 'Belt'
    assert_includes list, 'Straps'
    assert_equal 2, list.length
  end

  test 'equipment_badges returns badge hashes' do
    @set.belt = true
    badges = @set.equipment_badges
    assert_equal 1, badges.length
    assert_equal 'B', badges.first[:label]
    assert_equal 'Belt', badges.first[:title]
    assert badges.first[:color].present?
  end

  # --- Outcomes ---

  test 'outcome_badges includes failed badge' do
    @set.is_failed = true
    badges = @set.outcome_badges
    labels = badges.map { |b| b[:label] }
    assert_includes labels, '✗'
  end

  test 'outcome_badges includes spotter badge' do
    @set.spotter_assisted = true
    badges = @set.outcome_badges
    labels = badges.map { |b| b[:label] }
    assert_includes labels, 'SP'
  end

  test 'outcome_badges includes pain badge' do
    @set.pain_flag = true
    badges = @set.outcome_badges
    labels = badges.map { |b| b[:label] }
    assert_includes labels, '⚡'
  end

  test 'outcome_badges includes BFR badge' do
    @set.is_bfr = true
    badges = @set.outcome_badges
    labels = badges.map { |b| b[:label] }
    assert_includes labels, 'BFR'
  end

  test 'outcome_badges empty when no outcomes' do
    assert_empty @set.outcome_badges
  end

  # --- PR Scope Labels ---

  test 'pr_scope_label returns nil when set is not a PR' do
    set = create_pr_scope_candidate(previous_weight: 120, current_weight: 100, equipped: false)
    assert_nil set.pr_scope_label
  end

  test 'pr_scope_label returns RAW PR when PR is unequipped' do
    set = create_pr_scope_candidate(previous_weight: 90, current_weight: 100, equipped: false)
    assert_equal 'RAW PR', set.pr_scope_label
  end

  test 'pr_scope_label returns EQ PR when PR is equipped' do
    set = create_pr_scope_candidate(previous_weight: 100, current_weight: 110, equipped: true)
    assert_equal 'EQ PR', set.pr_scope_label
  end

  # --- Partial Reps ---

  test 'partial_reps validates numericality' do
    @set.partial_reps = -1
    assert_not @set.valid?
  end

  test 'partial_reps accepts positive integer' do
    @set.partial_reps = 3
    assert @set.valid?
  end

  test 'partial_reps accepts nil' do
    @set.partial_reps = nil
    assert @set.valid?
  end

  # --- Accommodating Resistance ---

  test 'has_accommodating_resistance? true with bands' do
    @set.band_tension_kg = 10
    assert @set.has_accommodating_resistance?
  end

  test 'has_accommodating_resistance? true with chains' do
    @set.chain_weight_kg = 20
    assert @set.has_accommodating_resistance?
  end

  test 'has_accommodating_resistance? false when neither' do
    assert_not @set.has_accommodating_resistance?
  end

  test 'band_tension_kg validates greater than 0' do
    @set.band_tension_kg = 0
    assert_not @set.valid?
    @set.band_tension_kg = -5
    assert_not @set.valid?
  end

  test 'chain_weight_kg validates greater than 0' do
    @set.chain_weight_kg = 0
    assert_not @set.valid?
    @set.chain_weight_kg = -5
    assert_not @set.valid?
  end

  test 'total_load_kg sums weight + bands + chains' do
    @set.weight_kg = 100
    @set.band_tension_kg = 15
    @set.chain_weight_kg = 20
    assert_equal 135, @set.total_load_kg
  end

  test 'total_load_kg works with only weight' do
    @set.weight_kg = 100
    @set.band_tension_kg = nil
    @set.chain_weight_kg = nil
    assert_equal 100, @set.total_load_kg
  end

  # --- Scopes ---

  test 'equipped scope finds sets with equipment' do
    @set.update!(belt: true)
    assert_includes ExerciseSet.equipped, @set
  end

  test 'with_pain scope finds flagged sets' do
    @set.update!(pain_flag: true)
    assert_includes ExerciseSet.with_pain, @set
  end

  test 'failed scope finds failed sets' do
    @set.update!(is_failed: true)
    assert_includes ExerciseSet.failed, @set
  end

  test 'bfr scope finds BFR sets' do
    @set.update!(is_bfr: true)
    assert_includes ExerciseSet.bfr, @set
  end
end
