module ApplicationHelper
  # Bootstrap icons for each equipment type
  def equipment_icon(equipment_type)
    icons = {
      'barbell' => '<i class="bi bi-grip-horizontal"></i>',
      'dumbbell' => '<i class="bi bi-box-fill"></i>',
      'machine' => '<i class="bi bi-gear-fill"></i>',
      'cables' => '<i class="bi bi-arrow-down-up"></i>',
      'bodyweight' => '<i class="bi bi-person-fill"></i>',
      'kettlebell' => '<i class="bi bi-droplet-fill"></i>',
      'bands' => '<i class="bi bi-bandaid-fill"></i>',
      'smith_machine' => '<i class="bi bi-grid-3x3-gap-fill"></i>',
      'other' => '<i class="bi bi-question-circle"></i>'
    }
    icons[equipment_type]&.html_safe || '<i class="bi bi-question-circle"></i>'.html_safe
  end

  # Format exercise type with icon
  def exercise_type_badge(exercise)
    case exercise.exercise_type
    when 'reps'
      '<span class="badge bg-primary"><i class="bi bi-123 me-1"></i>Reps</span>'.html_safe
    when 'time'
      '<span class="badge bg-info"><i class="bi bi-clock me-1"></i>Time</span>'.html_safe
    when 'distance'
      '<span class="badge bg-success"><i class="bi bi-geo-alt me-1"></i>Distance</span>'.html_safe
    end
  end

  # Get last weight used for this exercise in this workout
  def last_weight_for(workout_exercise)
    last_set = workout_exercise.exercise_sets.order(created_at: :desc).first
    if last_set&.weight_kg
      Current.user.display_weight(last_set.weight_kg)&.round
    elsif workout_exercise.previous_exercise
      prev_set = workout_exercise.previous_exercise.exercise_sets.order(created_at: :desc).first
      prev_set&.weight_kg ? Current.user.display_weight(prev_set.weight_kg)&.round : nil
    end
  end

  # Get last reps used for this exercise in this workout
  def last_reps_for(workout_exercise)
    last_set = workout_exercise.exercise_sets.order(created_at: :desc).first
    if last_set&.reps
      last_set.reps
    elsif workout_exercise.previous_exercise
      prev_set = workout_exercise.previous_exercise.exercise_sets.order(created_at: :desc).first
      prev_set&.reps
    end
  end

  # Format large numbers with SI units (K, M, etc.)
  def number_to_si(number)
    return '0' if number.nil? || number.zero?

    if number >= 1_000_000
      "#{(number / 1_000_000.0).round(1)}M"
    elsif number >= 1_000
      "#{(number / 1_000.0).round(1)}K"
    else
      number.to_s
    end
  end

  # Display weight in user's preferred unit with suffix
  # @param kg_value [Numeric] weight in kilograms
  # @param precision [Integer] decimal places (default: 0)
  # @return [String] formatted weight like "135lbs" or "60kg"
  def weight_display(kg_value, precision: 0)
    WeightConverter.format(kg_value, user: Current.user, precision: precision)
  end

  # Display weight value without unit suffix
  # @param kg_value [Numeric] weight in kilograms
  # @return [Numeric] display value in user's unit
  def weight_value(kg_value)
    WeightConverter.display(kg_value, user: Current.user)
  end

  # User's preferred unit string
  def weight_unit
    Current.user&.preferred_unit || 'kg'
  end

  # Format seconds as M:SS
  def format_seconds(seconds)
    minutes = seconds / 60
    secs = seconds % 60
    format('%d:%02d', minutes, secs)
  end
end
