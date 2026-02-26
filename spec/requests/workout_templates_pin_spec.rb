require 'rails_helper'

RSpec.describe 'Workout template pinning', type: :request do
  let(:user) { users(:one) }
  let(:template) { workout_templates(:one) }

  before do
    sign_in_as(user)
  end

  it 'returns the pin turbo frame for turbo-frame html requests' do
    frame_id = ActionView::RecordIdentifier.dom_id(template, :pin)

    post toggle_pin_workout_template_path(template), headers: { 'Turbo-Frame' => frame_id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(turbo-frame id="#{frame_id}"))
    expect(response.body).to include('bi bi-pin-angle')
  end
end
