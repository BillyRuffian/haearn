module WeeklySummaryMailerHelper
  def weekly_summary_number(value, precision: 1)
    number = value.to_f.round(precision)
    number = number.to_i if number == number.to_i
    number_with_delimiter(number)
  end

  def weekly_summary_duration(minutes)
    minutes = minutes.to_f
    return "#{minutes.round} min" if minutes < 60

    "#{weekly_summary_number(minutes / 60, precision: 1)} hr"
  end

  def weekly_summary_comparison(percent, baseline_weeks)
    return 'No prior baseline' if percent.nil?

    sign = percent.positive? ? '+' : ''
    "#{sign}#{percent}% vs #{pluralize(baseline_weeks, 'week')} avg"
  end

  def weekly_summary_trend_class(percent)
    return 'trend-unavailable' if percent.nil?
    return 'trend-up' if percent.positive?
    return 'trend-down' if percent.negative?

    'trend-flat'
  end
end
