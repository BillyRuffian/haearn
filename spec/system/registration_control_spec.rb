require 'rails_helper'

RSpec.describe 'Admin registration switch', type: :system do
  it 'saves the switch in both directions and updates the sign-up screen' do
    session = users(:admin).sessions.create!
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id
    page.driver.browser.set_cookie("session_id=#{jar[:session_id]}")

    visit admin_root_path
    expect(page).to have_checked_field('Allow new user registrations')
    uncheck 'Allow new user registrations'
    click_button 'Save registration settings'
    expect(page).to have_content('New user registrations are disabled.')
    expect(page).to have_unchecked_field('Allow new user registrations')

    visit new_registration_path
    expect(page).to have_content('Registrations are currently closed')
    expect(page).not_to have_button('Create Account')

    visit admin_root_path
    check 'Allow new user registrations'
    click_button 'Save registration settings'
    expect(page).to have_content('New user registrations are enabled.')
    expect(page).to have_checked_field('Allow new user registrations')

    visit new_registration_path
    expect(page).to have_button('Create Account', disabled: true)
  end
end
