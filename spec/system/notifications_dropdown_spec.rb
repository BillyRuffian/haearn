require 'rails_helper'

RSpec.describe 'Notifications dropdown', type: :system, js: true do
  let(:user) { users(:system) }
  let(:unread_notification) { notifications(:system_unread_readiness) }

  before do
    sign_in_via_ui(user)
  end

  def open_dropdown(button_selector)
    page.execute_script(<<~JS, button_selector)
      const button = document.querySelector(arguments[0])
      if (!button) throw new Error(`Missing dropdown button: ${arguments[0]}`)

      if (window.bootstrap?.Dropdown) {
        window.bootstrap.Dropdown.getOrCreateInstance(button).show()
      } else {
        button.click()
      }
    JS
  end

  it 'loads notifications into the dropdown and marks them all read' do
    visit root_path

    within("li.nav-item.dropdown[data-controller='notifications-center']", visible: true) do
      expect(page).to have_css("[data-notifications-center-target='badge']", visible: true)
    end

    open_dropdown("li.nav-item.dropdown[data-controller='notifications-center'] button[aria-label='Notifications']")

    expect(page).to have_css(".notification-item", text: unread_notification.title)
    expect(page).to have_css(".notification-item", text: unread_notification.message)

    within("li.nav-item.dropdown[data-controller='notifications-center']", visible: true) do
      click_button 'Mark all read'
      expect(page).to have_no_css("[data-notifications-center-target='badge']", visible: true)
    end

    expect(unread_notification.reload).to be_read
  end

  it 'keeps the mobile notifications dropdown within the viewport on phone widths' do
    visit root_path
    page.current_window.resize_to(390, 844)

    open_dropdown("div.d-lg-none div.dropdown[data-controller='notifications-center'] button[aria-label='Notifications']")
    expect(page).to have_css(".notifications-dropdown-mobile.show")

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const menu = document.querySelector(".notifications-dropdown-mobile.show")
        if (!menu) return null

        const rect = menu.getBoundingClientRect()
        return {
          left: rect.left,
          right: rect.right,
          viewportWidth: window.innerWidth
        }
      })()
    JS

    expect(metrics).not_to be_nil
    expect(metrics["left"]).to be >= 0
    expect(metrics["right"]).to be <= metrics["viewportWidth"]
  end
end
