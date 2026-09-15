module Admin::AiUsageHelper
  def ai_cost_usd(amount)
    return 'Unavailable' if amount.nil?
    return '< $0.0001' if amount.positive? && amount < BigDecimal('0.0001')

    number_to_currency(amount, precision: 4)
  end
end
