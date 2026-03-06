require 'rails_helper'

RSpec.describe 'Notifications dropdown', type: :system, js: true do
  let(:user) { users(:system) }
  let(:unread_notification) { notifications(:system_unread_readiness) }

  before do
    sign_in_via_ui(user)
  end

  it 'loads notifications into the dropdown and marks them all read' do
    visit root_path

    within("li.nav-item.dropdown[data-controller='notifications-center']", visible: true) do
      expect(page).to have_css("[data-notifications-center-target='badge']", text: '1', visible: true)

      find("button[aria-label='Notifications']", visible: true).click

      expect(page).to have_css(".notification-item", text: unread_notification.title)
      expect(page).to have_css(".notification-item", text: unread_notification.message)

      click_button 'Mark all read'

      expect(page).to have_no_css("[data-notifications-center-target='badge']", text: '1', visible: true)
    end

    expect(unread_notification.reload).to be_read
  end
end
