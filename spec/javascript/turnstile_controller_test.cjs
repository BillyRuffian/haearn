const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const vm = require('node:vm')

function harness({ loaded = true } = {}) {
  const calls = { renders: [], resets: [], removes: [], scripts: [] }
  const turnstile = {
    render: (element, options) => { calls.renders.push(options); return 0 },
    reset: id => calls.resets.push(id),
    remove: id => calls.removes.push(id)
  }
  const window = loaded ? { turnstile } : {}
  const context = vm.createContext({
    Controller: class {}, window, setTimeout, clearTimeout,
    document: {
      createElement: () => ({ remove() { this.removed = true } }),
      head: { appendChild: script => calls.scripts.push(script) }
    }
  })
  const source = readFileSync('app/javascript/controllers/turnstile_controller.js', 'utf8')
    .replace(/^import .*\n/, '').replace('export default class', 'globalThis.TurnstileController = class')
  vm.runInContext(source, context)
  const controller = new context.TurnstileController()
  controller.siteKeyValue = 'public-key'
  controller.widgetTarget = { replaceChildren() {} }
  controller.statusTarget = { textContent: '' }
  controller.submitTarget = { disabled: false }
  controller.retryTarget = { hidden: true }
  const flush = async () => { await new Promise(resolve => setImmediate(resolve)) }
  return { controller, calls, window, turnstile, flush }
}

test('signup stays disabled until verified and resets after submission or expiry', async () => {
  const h = harness()
  h.controller.connect()
  assert.equal(h.controller.submitTarget.disabled, true)
  await h.flush()
  const options = h.calls.renders[0]
  assert.equal(options.action, 'signup')
  assert.equal(options.sitekey, 'public-key')
  assert.equal(options.theme, 'dark')
  options.callback('fresh-token')
  assert.equal(h.controller.submitTarget.disabled, false)
  h.controller.reset()
  assert.equal(h.controller.submitTarget.disabled, true)
  assert.deepEqual(h.calls.resets, [0])
  options.callback('another-token')
  options['expired-callback']()
  assert.equal(h.controller.submitTarget.disabled, true)
  assert.deepEqual(h.calls.resets, [0, 0])
})

test('timeouts and widget errors offer a retry and never enable signup', async () => {
  const h = harness()
  h.controller.connect()
  await h.flush()
  for (const name of ['timeout-callback', 'error-callback']) {
    h.calls.renders[0][name]()
    assert.equal(h.controller.submitTarget.disabled, true)
    assert.equal(h.controller.retryTarget.hidden, false)
    h.controller.retry()
    assert.equal(h.controller.retryTarget.hidden, true)
  }
  assert.deepEqual(h.calls.resets, [0, 0])
})

test('Turbo cache teardown removes the widget and ignores late callbacks', async () => {
  const h = harness()
  h.controller.connect()
  await h.flush()
  h.controller.teardown()
  h.calls.renders[0].callback('late-token')
  assert.equal(h.controller.submitTarget.disabled, true)
  assert.deepEqual(h.calls.removes, [0])
  h.controller.disconnect()
  assert.deepEqual(h.calls.removes, [0])
  h.controller.connect()
  await h.flush()
  assert.equal(h.calls.renders.length, 2)
})

test('script load failure can be retried without leaving a broken loader promise', async () => {
  const h = harness({ loaded: false })
  h.controller.connect()
  h.calls.scripts[0].onerror()
  await h.flush()
  assert.equal(h.controller.retryTarget.hidden, false)
  assert.equal(h.controller.submitTarget.disabled, true)
  assert.equal(h.calls.scripts[0].removed, true)
  h.controller.retry()
  assert.equal(h.calls.scripts.length, 2)
  h.window.turnstile = h.turnstile
  h.calls.scripts[1].onload()
  await h.flush()
  assert.equal(h.calls.renders.length, 1)
})

test('navigation away during script loading does not render a detached widget', async () => {
  const h = harness({ loaded: false })
  h.controller.connect()
  h.controller.disconnect()
  h.window.turnstile = h.turnstile
  h.calls.scripts[0].onload()
  await h.flush()
  assert.equal(h.calls.renders.length, 0)
})
