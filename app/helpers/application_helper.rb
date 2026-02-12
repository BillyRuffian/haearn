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
  # Falls back to the corresponding set from the previous session (set-for-set matching)
  def last_weight_for(workout_exercise)
    last_set = workout_exercise.exercise_sets.order(created_at: :desc).first
    if last_set&.weight_kg
      Current.user.format_weight(last_set.weight_kg)
    else
      prev_set = corresponding_previous_set(workout_exercise)
      prev_set&.weight_kg ? Current.user.format_weight(prev_set.weight_kg) : nil
    end
  end

  # Get last reps used for this exercise in this workout
  # Falls back to the corresponding set from the previous session (set-for-set matching)
  def last_reps_for(workout_exercise)
    last_set = workout_exercise.exercise_sets.order(created_at: :desc).first
    if last_set&.reps
      last_set.reps
    else
      corresponding_previous_set(workout_exercise)&.reps
    end
  end

  # Get last duration used for this exercise in this workout
  def last_duration_for(workout_exercise)
    last_set = workout_exercise.exercise_sets.order(created_at: :desc).first
    if last_set&.duration_seconds
      last_set.duration_seconds
    else
      corresponding_previous_set(workout_exercise)&.duration_seconds
    end
  end

  # Get last distance used for this exercise in this workout
  def last_distance_for(workout_exercise)
    last_set = workout_exercise.exercise_sets.order(created_at: :desc).first
    if last_set&.distance_meters
      last_set.distance_meters
    else
      corresponding_previous_set(workout_exercise)&.distance_meters
    end
  end

  # Get the corresponding set from the previous session for set-for-set matching
  # For the Nth set being added, returns the Nth set from last time
  # Falls back to the last set from the previous session if no Nth set exists
  def corresponding_previous_set(workout_exercise)
    prev_exercise = workout_exercise.previous_exercise
    return nil unless prev_exercise

    prev_sets = prev_exercise.exercise_sets.order(:position, :created_at).to_a
    return nil if prev_sets.empty?

    # The next set number is current count + 1 (0-indexed for array)
    next_set_index = workout_exercise.exercise_sets.count
    prev_sets[next_set_index] || prev_sets.last
  end

  # Get all sets from the previous session for copy-last UI
  # Returns array of hashes with display-ready values
  def previous_session_sets(workout_exercise)
    prev_exercise = workout_exercise.previous_exercise
    return [] unless prev_exercise

    prev_exercise.exercise_sets.order(:position, :created_at).map do |set|
      {
        weight: set.weight_kg ? Current.user.format_weight(set.weight_kg) : nil,
        reps: set.reps,
        duration_seconds: set.duration_seconds,
        distance_meters: set.distance_meters,
        is_warmup: set.is_warmup
      }
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

  # Safely sanitize a return_to URL to prevent XSS via javascript: URLs
  # Only allows relative paths starting with /
  def safe_return_to(url, fallback: root_path)
    return fallback if url.blank?

    # Parse the URL and only allow relative paths (starting with /)
    # Reject javascript:, data:, external URLs, protocol-relative URLs, etc.
    uri = URI.parse(url.to_s)

    # Only allow paths with no scheme and no host (relative URLs)
    if uri.scheme.nil? && uri.host.nil? && url.to_s.start_with?('/')
      url
    else
      fallback
    end
  rescue URI::InvalidURIError
    fallback
  end

  # Generate shareable workout text
  def generate_workout_text(workout)
    lines = []

    # Header
    date_str = workout.started_at.strftime('%A, %B %-d, %Y')
    lines << "🏋️ #{date_str}"
    lines << "📍 #{workout.gym.name}" if workout.gym
    lines << "⏱️ #{workout.duration_minutes} min" if workout.finished_at
    lines << ''

    # Exercises grouped by block
    workout.workout_blocks.includes(workout_exercises: [ :exercise, :machine, :exercise_sets ]).order(:position).each do |block|
      block.workout_exercises.order(:position).each do |we|
        exercise_name = we.exercise&.name || 'Unknown Exercise'
        machine_suffix = we.machine ? " (#{we.machine.name})" : ''
        lines << "#{exercise_name}#{machine_suffix}"

        we.exercise_sets.order(:position).each_with_index do |set, idx|
          set_line = format_set_text(set, idx + 1, workout.user.preferred_unit)
          lines << set_line
        end
        lines << ''
      end
    end

    # Notes
    if workout.notes.present?
      lines << "📝 Notes: #{workout.notes}"
      lines << ''
    end

    lines.join("\n").strip
  end

  # Format a single set as text
  def format_set_text(set, set_num, unit)
    warmup_tag = set.is_warmup ? ' (warmup)' : ''

    if set.weight_kg.present? && set.reps.present?
      weight = unit == 'lbs' ? (set.weight_kg * 2.20462).round(1) : set.weight_kg.round(1)
      "Set #{set_num}: #{set.reps} × #{weight}#{unit}#{warmup_tag}"
    elsif set.reps.present?
      "Set #{set_num}: #{set.reps} reps#{warmup_tag}"
    elsif set.duration_seconds.present?
      mins = set.duration_seconds / 60
      secs = set.duration_seconds % 60
      duration_str = mins > 0 ? "#{mins}m #{secs}s" : "#{secs}s"
      "Set #{set_num}: #{duration_str}#{warmup_tag}"
    elsif set.distance_meters.present?
      "Set #{set_num}: #{set.distance_meters}m#{warmup_tag}"
    else
      "Set #{set_num}: completed#{warmup_tag}"
    end
  end
end
