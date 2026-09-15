module WorkoutAnalysesHelper
  def coaching_status_class(status)
    { 'progressing' => 'text-bg-success', 'stable' => 'text-bg-secondary',
      'possible_plateau' => 'text-bg-warning', 'regressing' => 'text-bg-warning',
      'insufficient_data' => 'text-bg-secondary' }.fetch(status, 'text-bg-secondary')
  end

  def coaching_target_weight(feedback, context)
    weight = feedback.dig('next_session', 'weight_kg')
    return unless weight

    if context['machine_id']
      ratio = context['machine_weight_ratio'].to_f
      weight /= ratio if ratio.positive?
    end
    unit = context['display_unit'].presence || Current.user.preferred_unit
    "#{number_with_precision(WeightConverter.from_kg(weight, unit), precision: 2, strip_insignificant_zeros: true)} #{unit}"
  end
end
