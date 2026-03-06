require 'rails_helper'

RSpec.describe 'Offline sync confidence', type: :system, js: true do
  let(:user) { users(:system) }

  before do
    sign_in_via_ui(user)
    reset_offline_storage
  end

  after do
    reset_offline_storage
  end

  it 'shows queued state and exposes retry when sync fails' do
    visit root_path

    seed_offline_pending_item(
      "id" => 1,
      "url" => workouts_path,
      "method" => "POST",
      "data" => { "example" => "payload" }
    )

    page.execute_script("window.localStorage.setItem('haearn:last-synced-at', '1706000000000')")
    visit root_path

    within("[data-offline-target='confidence']", visible: true) do
      expect(page).to have_css("[data-offline-target='status']", text: /\AQueued\z/i, visible: :visible)
      expect(page).to have_css("[data-offline-target='queueCount']", text: '1', visible: true)
      expect(page).to have_css("[data-offline-target='lastSynced']", text: /Last synced:/i, visible: :visible)
      expect(page).to have_button('Sync now', exact: false)
    end

    page.execute_script(<<~JS)
      window.__haearnOriginalFetch = window.fetch.bind(window)
      window.fetch = (url, options = {}) => {
        if ((options.method || "GET").toUpperCase() !== "GET") {
          return Promise.reject(new Error("forced sync failure"))
        }

        return window.__haearnOriginalFetch(url, options)
      }
    JS

    within("[data-offline-target='confidence']", visible: true) do
      click_button 'Sync now'
      expect(page).to have_css("[data-offline-target='status']", text: /\ASync failed\z/i, visible: :visible)
      expect(page).to have_button('Retry', exact: false)
      expect(page).to have_css("[data-offline-target='queueCount']", text: '1', visible: true)
    end
  end
end
