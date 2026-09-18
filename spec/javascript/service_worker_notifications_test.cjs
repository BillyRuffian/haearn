const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const vm = require('node:vm')

function worker({ badgeSupported = true } = {}) {
  const handlers = {}, badges = [], shown = [], requests = [], messages = [], opened = []
  const state = { count: 2, user: 1, offline: false, unauthorized: false, failure: false }
  const fetch = async (request, options = {}) => {
    const url = typeof request === 'string' ? request : request.url
    requests.push({ url, options })
    if (state.offline) throw new Error('Offline')
    if (url.endsWith('/read') && options.method === 'PATCH') state.count--
    return {
      ok: !state.unauthorized && !state.failure,
      status: state.unauthorized ? 401 : state.failure ? 500 : 200,
      redirected: false,
      json: async () => ({ unread_count: state.count, user_id: state.user, csrf_token: 'csrf-test' })
    }
  }
  const client = { url: 'https://haearn.test/', postMessage: data => messages.push(data), focus: async () => {} }
  const self = {
    location: { origin: 'https://haearn.test' },
    navigator: badgeSupported ? {
      setAppBadge: async count => badges.push(['set', count]),
      clearAppBadge: async () => badges.push(['clear'])
    } : {},
    addEventListener: (name, callback) => { handlers[name] = callback },
    clients: {
      claim: async () => {}, matchAll: async () => [client],
      openWindow: async url => { opened.push(url) }
    },
    registration: {
      showNotification: async (title, options) => shown.push({ title, options }),
      getNotifications: async () => []
    }
  }
  const context = vm.createContext({ self, location: self.location, URL, fetch, console,
    caches: { keys: async () => [], delete: async () => {}, match: async () => { throw new Error('Must not read cached status') } }
  })
  vm.runInContext(readFileSync(resolve(__dirname, '../../app/views/pwa/service-worker.js'), 'utf8'), context)
  async function emit(name, data = {}) {
    const pending = []
    handlers[name]({ ...data, waitUntil: promise => pending.push(promise), respondWith: promise => pending.push(promise) })
    if (name !== 'fetch') assert.equal(pending.length, 1, 'event lifetime must be extended synchronously')
    await Promise.all(pending)
  }
  return { state, badges, shown, requests, messages, opened, emit, client, self }
}

test('a push displays a notification and sets the current server count instead of stale payload data', async () => {
  const w = worker()
  w.state.count = 3
  await w.emit('push', { data: { json: () => ({ title: 'Review ready', options: { data: { kind: 'workout_analysis' } }, unread_count: 99 }) } })
  assert.equal(w.shown[0].title, 'Review ready')
  assert.deepEqual(w.badges, [['set', 3]])
  assert.equal(w.requests[0].options.cache, 'no-store')
  assert.equal(w.requests[0].options.credentials, 'same-origin')
  assert.equal(w.messages[0].type, 'NOTIFICATIONS_CHANGED')
})

test('offline push uses the supplied count, then resume fetches and clears a read badge', async () => {
  const w = worker()
  w.state.offline = true
  await w.emit('push', { data: { json: () => ({ title: 'Review ready', unread_count: 4 }) } })
  assert.deepEqual(w.badges, [['set', 4]])
  w.state.offline = false
  w.state.count = 0
  await w.emit('message', { data: { type: 'REFRESH_NOTIFICATION_BADGE' } })
  assert.deepEqual(w.badges.at(-1), ['clear'])
})

test('network/server failures keep the previous badge rather than interpreting them as zero', async () => {
  const w = worker()
  w.state.failure = true
  await w.emit('message', { data: { type: 'REFRESH_NOTIFICATION_BADGE' } })
  w.state.offline = true
  await w.emit('message', { data: { type: 'REFRESH_NOTIFICATION_BADGE' } })
  assert.deepEqual(w.badges, [])
})

test('sign-out clears the badge even if a late push contains an old count', async () => {
  const w = worker()
  w.state.unauthorized = true
  await w.emit('push', { data: { json: () => ({ title: 'Review ready', unread_count: 9 }) } })
  assert.deepEqual(w.badges, [['clear']])
})

test('banner cleanup failures cannot restore a stale badge after sign-out', async () => {
  const w = worker()
  w.state.unauthorized = true
  w.self.registration.getNotifications = async () => { throw new Error('Unavailable') }
  await w.emit('push', { data: { json: () => ({ title: 'Review ready', unread_count: 9 }) } })
  assert.deepEqual(w.badges, [['clear']])
})

test('notification clicks open the exact review, authenticate the read, and reconcile remaining unread count', async () => {
  const w = worker()
  let closed = false
  await w.emit('notificationclick', { notification: { close: () => { closed = true }, data: {
    kind: 'workout_analysis', notification_id: 7, user_id: 1, path: '/workouts/4?analysis_id=5#ai-coaching'
  } } })
  assert.equal(closed, true)
  assert.equal(w.opened[0], 'https://haearn.test/workouts/4?analysis_id=5#ai-coaching')
  assert.equal(w.requests.find(row => row.options.method === 'PATCH').options.headers['X-CSRF-Token'], 'csrf-test')
  assert.deepEqual(w.badges.at(-1), ['set', 1])
})

test('a last-review click clears the badge and focuses an already open matching window', async () => {
  const w = worker()
  w.state.count = 1
  w.client.url = 'https://haearn.test/workouts/4?analysis_id=5#ai-coaching'
  let focused = false
  w.client.focus = async () => { focused = true }
  await w.emit('notificationclick', { notification: { close: () => {}, data: {
    kind: 'workout_analysis', notification_id: 7, user_id: 1, path: '/workouts/4?analysis_id=5#ai-coaching'
  } } })
  assert.equal(focused, true)
  assert.deepEqual(w.badges.at(-1), ['clear'])
})

test('clicks cannot read another signed-in account notification or navigate off-origin', async () => {
  const w = worker()
  w.client.url = 'https://haearn.test/settings'
  await w.emit('notificationclick', { notification: { close: () => {}, data: {
    kind: 'workout_analysis', notification_id: 7, user_id: 2, path: 'https://other.test/private'
  } } })
  assert.equal(w.requests.some(row => row.options.method === 'PATCH'), false)
  assert.equal(w.opened[0], 'https://haearn.test/')
})

test('dismissal refreshes status without marking a review read', async () => {
  const w = worker()
  await w.emit('notificationclose')
  assert.equal(w.requests.some(row => row.options.method === 'PATCH'), false)
  assert.deepEqual(w.badges, [['set', 2]])
})

test('activation and background sync reconcile badges while preserving workout sync messages', async () => {
  const w = worker()
  w.state.count = 0
  await w.emit('activate')
  await w.emit('sync', { tag: 'sync-workouts' })
  assert.deepEqual(w.badges, [['clear'], ['clear']])
  assert.equal(w.messages[0].type, 'SYNC_WORKOUTS')
})

test('badge support is optional and malformed push payloads still produce visible notifications', async () => {
  const w = worker({ badgeSupported: false })
  await w.emit('push', { data: { json: () => { throw new Error('Invalid JSON') } } })
  assert.equal(w.shown.length, 1)
  assert.deepEqual(w.badges, [])
})

test('notification status/feed fetches bypass all service-worker caches', async () => {
  const w = worker()
  for (const path of ['/notifications/status', '/notifications/feed']) {
    await w.emit('fetch', { request: { url: `https://haearn.test${path}`, method: 'GET' } })
  }
  assert.equal(w.requests.length, 2)
})
