# Pure calculations shared by workout coaching and future weekly reviews.
# Sessions are hashes with chronological working sets; history is newest first.
class TrainingProgressionCalculator
  def initialize(current:, history:, weighted_reps:, target: nil)
    @current, @history, @weighted_reps, @target = current, history, weighted_reps, target
  end

  def call
    current = metrics(@current)
    previous = @history.first && metrics(@history.first)
    {
      working_sets: @current.fetch(:sets).size,
      previous_session_sets: @history.first&.fetch(:sets),
      load_volume_kg_reps: current[:volume]&.round(3),
      previous_load_volume_kg_reps: previous&.fetch(:volume)&.round(3),
      volume_change_percent: percentage(current[:volume], previous&.fetch(:volume)),
      best_set: current[:best],
      estimated_1rm_kg: current[:e1rm],
      estimated_1rm_change_percent: percentage(current[:e1rm], previous&.fetch(:e1rm)),
      consecutive_sessions_at_current_load: consecutive_load_sessions,
      programmed_rep_target_reached: target_reached?,
      recent_trend: trend,
      recent_performance_regression: regression?,
      historical_sessions: @history.size
    }
  end

  private

  def metrics(session)
    sets = session.fetch(:sets)
    weighted = @weighted_reps && sets.any?
    volume = weighted && sets.all? { |set| set[:weight_kg] && set[:reps] } ? sets.sum { |set| set[:weight_kg] * set[:reps] } : nil
    estimates = weighted ? sets.filter_map do |set|
      next if set[:is_failed] || set[:spotter_assisted] || set[:partial_reps] || set[:band_tension_kg] || set[:chain_weight_kg]
      next unless set[:reps]&.between?(1, 10) && set[:set_type] == 'normal'

      value = OneRmCalculator.calculate(set[:weight_kg], set[:reps])
      [ set, value ] if value
    end : []
    best = estimates.max_by(&:last)
    { volume: volume, best: best&.first, e1rm: best&.last }
  end

  def percentage(current, previous)
    return unless current && previous&.positive?

    ((current - previous) / previous.to_f * 100).round(1)
  end

  def load_signature(session)
    sets = session.fetch(:sets)
    return if sets.empty? || sets.any? { |set| set[:weight_kg].nil? }

    sets.map { |set| set[:weight_kg] }.uniq.sort
  end

  def consecutive_load_sessions
    signature = load_signature(@current)
    return unless @weighted_reps && signature

    1 + @history.take_while { |session| load_signature(session) == signature }.size
  end

  def target_reached?
    return unless @target && @target[:sets]&.positive? && @target[:reps]&.positive?

    sets = @current.fetch(:sets)
    return false if sets.size < @target[:sets]

    sets.first(@target[:sets]).all? do |set|
      !set[:is_failed] && !set[:spotter_assisted] && set[:reps].to_i >= @target[:reps] &&
        (@target[:weight_kg].nil? || set[:weight_kg].to_f >= @target[:weight_kg])
    end
  end

  # Compare reps only at the same set count/load profile. e1RM is a fallback
  # when loading changed, and is deliberately restricted to normal 1–10 rep sets.
  def performance_pair(newer, older)
    new_sets, old_sets = newer.fetch(:sets), older.fetch(:sets)
    return if new_sets.empty? || old_sets.empty?
    return if (new_sets + old_sets).any? { |set| set[:is_failed] || set[:spotter_assisted] || set[:partial_reps] }

    if new_sets.size == old_sets.size && new_sets.map { |set| set[:weight_kg] } == old_sets.map { |set| set[:weight_kg] } &&
        (new_sets + old_sets).all? { |set| set[:reps] && set[:set_type] == 'normal' }
      return [ new_sets.sum { |set| set[:reps] }, old_sets.sum { |set| set[:reps] } ]
    end
    newer_e1rm, older_e1rm = metrics(newer)[:e1rm], metrics(older)[:e1rm]
    [ newer_e1rm, older_e1rm ] if newer_e1rm && older_e1rm
  end

  def trend
    comparisons = ([ @current ] + @history).each_cons(2).first(3).map { |a, b| performance_pair(a, b) }
    return 'insufficient_data' if comparisons.empty? || comparisons.first.nil?

    current, previous = comparisons.first
    return 'progressing' if current > previous
    return 'regressing' if regression?
    return 'possible_plateau' if comparisons.size == 3 && comparisons.all? { |pair| pair && pair.first == pair.last }

    'stable'
  end

  def regression?
    return nil if @history.size < 2

    comparisons = ([ @current ] + @history.first(2)).each_cons(2).map { |a, b| performance_pair(a, b) }
    return nil if comparisons.any?(&:nil?)

    comparisons.all? { |current, previous| current < previous * 0.95 }
  end
end
