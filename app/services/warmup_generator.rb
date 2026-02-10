# Generates warmup sets for exercises based on working weight
# Provides intelligent warmup progression with appropriate rep schemes
class WarmupGenerator
  # Default warmup progression as percentages of working weight
  DEFAULT_PROGRESSION = [
    { percentage: 0.0, reps: 5, label: 'Bar' },      # Empty bar
    { percentage: 0.5, reps: 5, label: '50%' },      # 50% of working weight
    { percentage: 0.7, reps: 3, label: '70%' },      # 70% of working weight
    { percentage: 0.85, reps: 2, label: '85%' }      # 85% of working weight
  ].freeze

  # Standard barbell weight in kg and lbs
  BARBELL_WEIGHT_KG = 20
  BARBELL_WEIGHT_LBS = 45

  attr_reader :working_weight_kg, :user, :machine, :exercise

  # Initialize warmup generator
  # @param working_weight_kg [Float] target working weight in kg
  # @param user [User] current user for unit preferences
  # @param machine [Machine, nil] optional machine for equipment-specific logic
  # @param exercise [Exercise] exercise being warmed up for
  def initialize(working_weight_kg:, user:, machine: nil, exercise:)
    @working_weight_kg = working_weight_kg.to_f
    @user = user
    @machine = machine
    @exercise = exercise
  end

  # Generate warmup sets
  # @return [Array<Hash>] array of warmup set hashes with :weight_kg, :reps, :label
  def generate
    return [] unless exercise.has_weight?
    return [] if working_weight_kg <= 0

    warmups = []
    bar_weight = barbell_weight_kg

    DEFAULT_PROGRESSION.each do |step|
      weight = if step[:percentage].zero?
                 bar_weight # Empty bar
      else
                 bar_weight + (working_weight_kg - bar_weight) * step[:percentage]
      end

      # Skip this warmup if it's too close to working weight or too light
      next if weight >= working_weight_kg * 0.95 # Skip if within 5% of working weight
      next if step[:percentage] > 0 && weight <= bar_weight * 1.1 # Skip calculated warmups that are barely above bar

      warmups << {
        weight_kg: weight.round(1),
        reps: step[:reps],
        label: step[:label],
        is_warmup: true
      }
    end

    warmups
  end

  # Generate and create warmup sets for a workout exercise
  # @param workout_exercise [WorkoutExercise] the exercise to add warmups to
  # @return [Array<ExerciseSet>] created warmup sets
  def self.create_for(workout_exercise:, working_weight_kg:)
    generator = new(
      working_weight_kg: working_weight_kg,
      user: workout_exercise.workout.user,
      machine: workout_exercise.machine,
      exercise: workout_exercise.exercise
    )

    warmups = generator.generate
    created_sets = []

    warmups.each_with_index do |warmup_data, index|
      set = workout_exercise.exercise_sets.create(
        weight_kg: warmup_data[:weight_kg],
        reps: warmup_data[:reps],
        is_warmup: true,
        position: index + 1,
        completed_at: Time.current
      )
      created_sets << set if set.persisted?
    end

    created_sets
  end

  private

  # Get barbell weight based on user's preferred unit
  # @return [Float] barbell weight in kg
  def barbell_weight_kg
    # Check if this is a barbell or smith machine exercise
    return BARBELL_WEIGHT_KG if plate_loaded_equipment?

    # For machines/cables, start from 0
    0.0
  end

  # Check if exercise uses plate-loaded equipment (barbell/smith machine)
  # @return [Boolean]
  def plate_loaded_equipment?
    return false unless machine

    machine.equipment_type.in?(%w[barbell smith_machine])
  end
end
