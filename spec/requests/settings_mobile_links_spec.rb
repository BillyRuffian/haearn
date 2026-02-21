require 'rails_helper'

RSpec.describe 'Settings mobile quick links', type: :request do
  let(:user) { users(:one) }

  before do
    sign_in_as(user)
  end

  it 'includes body metrics quick link for PWA/mobile overflow navigation' do
    get settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(body_metrics_path)
    expect(response.body).to include('Body Metrics')
  end
end
