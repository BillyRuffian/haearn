module SystemTestHelpers
  def sign_in_via_ui(user, password: 'password')
    session = user.sessions.order(:id).first || user.sessions.create!(user_agent: 'System Test Browser', ip_address: '127.0.0.1')
    signed_session_id = ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = session.id
    end[:session_id]

    visit root_path
    page.driver.browser.manage.add_cookie(name: 'session_id', value: signed_session_id, path: '/')
    visit root_path
  end

  def reset_offline_storage
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      try { window.localStorage.removeItem("haearn:last-synced-at") } catch (_error) {}

      const request = indexedDB.deleteDatabase("haearn-offline")
      request.onsuccess = () => done(true)
      request.onerror = () => done(true)
      request.onblocked = () => done(true)
    JS
  end

  def seed_offline_pending_item(item)
    page.evaluate_async_script(<<~JS, item)
      const payload = arguments[0]
      const done = arguments[1]
      const request = indexedDB.open("haearn-offline", 1)

      request.onupgradeneeded = (event) => {
        const db = event.target.result
        if (!db.objectStoreNames.contains("pending")) {
          db.createObjectStore("pending", { keyPath: "id", autoIncrement: true })
        }
        if (!db.objectStoreNames.contains("exercises")) {
          db.createObjectStore("exercises", { keyPath: "id" })
        }
      }

      request.onerror = () => done(request.error?.message || "open failed")
      request.onsuccess = () => {
        const db = request.result
        const transaction = db.transaction(["pending"], "readwrite")
        const store = transaction.objectStore("pending")
        store.put(payload)
        transaction.oncomplete = () => done(true)
        transaction.onerror = () => done(transaction.error?.message || "transaction failed")
      }
    JS
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end
