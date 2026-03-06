# Displays the main dashboard with workout statistics, charts, and analytics
# Shows workout frequency, volume tracking, PR timeline, heatmaps, and more
class DashboardController < ApplicationController
  # GET /dashboard
  # Main dashboard view with comprehensive workout analytics
  def index
    return unless Current.user
    assign_dashboard_data(dashboard_page_data_builder.index_data)
  end

  # GET /analytics
  # Dedicated analytics page with all charts and trends
  def analytics
    return unless Current.user
    assign_dashboard_data(dashboard_page_data_builder.analytics_data)
  end

  private

  def dashboard_page_data_builder
    @dashboard_page_data_builder ||= DashboardPageDataBuilder.new(
      user: Current.user,
      analytics_fetcher: method(:fetch_cached_analytics)
    )
  end

  def assign_dashboard_data(data)
    data.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end

  def fetch_cached_analytics(key)
    DashboardAnalyticsCache.fetch(user_id: Current.user.id, key:) do
      dashboard_analytics_calculator.calculate(key)
    end
  end

  def dashboard_analytics_calculator
    @dashboard_analytics_calculator ||= DashboardAnalyticsCalculator.new(user: Current.user)
  end
end
