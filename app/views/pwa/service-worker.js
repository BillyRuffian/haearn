// Haearn Service Worker
// Provides offline support and caching for the PWA

const CACHE_VERSION = 'haearn-v8';
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const DYNAMIC_CACHE = `${CACHE_VERSION}-dynamic`;

// App shell - files needed for basic app functionality
const APP_SHELL = [
  '/',
  '/manifest.json'
];

const OPTIONAL_SHELL = [
  '/favicon.svg',
  '/favicon.ico',
  '/apple-touch-icon.png',
  '/web-app-manifest-192x192.png',
  '/web-app-manifest-512x512.png',
  '/icon.png',
  '/icon.svg'
];

// Install event - cache app shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then(async (cache) => {
        console.log('[SW] Caching app shell');
        await cache.addAll(APP_SHELL);
        await Promise.allSettled(OPTIONAL_SHELL.map((path) => cache.add(path)));
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => {
        return Promise.all(
          keys
            .filter((key) => key.startsWith('haearn-') && key !== STATIC_CACHE && key !== DYNAMIC_CACHE)
            .map((key) => {
              console.log('[SW] Removing old cache:', key);
              return caches.delete(key);
            })
        );
      })
      .then(() => self.clients.claim())
      .then(() => refreshNotificationBadge())
  );
});

// Fetch event - network-first for HTML/API, cache-first for assets
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Notification state is private and must never use an offline cached count.
  if (url.origin === location.origin && url.pathname.startsWith('/notifications')) {
    event.respondWith(fetch(request));
    return;
  }

  // Skip non-GET requests
  if (request.method !== 'GET') return;

  // Skip external requests
  if (url.origin !== location.origin) return;

  // Skip Turbo Stream requests
  if (request.headers.get('Accept')?.includes('text/vnd.turbo-stream.html')) return;

  // Network-first for HTML pages and API calls
  if (request.headers.get('Accept')?.includes('text/html') ||
    url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirst(request));
    return;
  }

  // Cache-first for static assets (JS, CSS, images)
  if (isStaticAsset(url.pathname)) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Network-first for everything else
  event.respondWith(networkFirst(request));
});

// Check if request is for a static asset
function isStaticAsset(pathname) {
  return pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot|ico)$/);
}

// Cache-first strategy - for static assets
async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) {
    return cached;
  }

  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.log('[SW] Cache-first fetch failed:', error);
    return new Response('Offline', { status: 503 });
  }
}

// Network-first strategy - for dynamic content
async function networkFirst(request) {
  try {
    const response = await fetch(request);
    if (response.ok && !response.headers.get('Cache-Control')?.includes('no-store')) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.log('[SW] Network-first fetch failed, trying cache');
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }

    // Return offline page for HTML requests
    if (request.headers.get('Accept')?.includes('text/html')) {
      const fallback = await caches.match('/');
      if (fallback) return fallback;
    }

    return new Response('Offline', { status: 503 });
  }
}

// Background sync for offline workouts
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-workouts') {
    event.waitUntil(Promise.all([syncOfflineWorkouts(), refreshNotificationBadge()]));
  }
});

async function syncOfflineWorkouts() {
  // This will be called when the app comes back online
  // The actual sync logic is handled by the Stimulus controller
  const clients = await self.clients.matchAll();
  clients.forEach((client) => {
    client.postMessage({ type: 'SYNC_WORKOUTS' });
  });
}

// Workers sleep between events. Reconcile with the server whenever the platform
// wakes us; never use a timer or a silent push to keep the worker alive.
let badgeRefresh = Promise.resolve();

async function notificationStatus() {
  const response = await fetch('/notifications/status', {
    credentials: 'same-origin', cache: 'no-store', headers: { Accept: 'application/json' }
  });
  if (response.status === 401) return { unread_count: 0, user_id: null };
  if (!response.ok || response.redirected) throw new Error('Notification status unavailable');
  const status = await response.json();
  if (!Number.isSafeInteger(status.unread_count) || status.unread_count < 0) throw new Error('Invalid unread count');
  return status;
}

async function applyNotificationBadge(count) {
  if (!Number.isSafeInteger(count) || count < 0) return;
  try {
    if (count === 0 && self.navigator.clearAppBadge) await self.navigator.clearAppBadge();
    else if (self.navigator.setAppBadge) await self.navigator.setAppBadge(count);
  } catch (_) { /* The browser or OS may disable icon badges. */ }
}

function refreshNotificationBadge(fallbackCount) {
  // Serialize updates so a slow earlier response cannot replace a newer count.
  badgeRefresh = badgeRefresh.catch(() => {}).then(async () => {
    let status;
    try {
      status = await notificationStatus();
    } catch (_) {
      // Offline is unknown, not zero. A received push can supply an initial count.
      await applyNotificationBadge(fallbackCount);
      return null;
    }
    await applyNotificationBadge(status.unread_count);
    if (status.unread_count === 0) {
      try {
        const displayed = await self.registration.getNotifications();
        displayed.filter(item => item.data?.kind === 'workout_analysis').forEach(item => item.close());
      } catch (_) { /* Banner cleanup must not overwrite an authoritative badge. */ }
    }
    return status;
  });
  return badgeRefresh;
}

async function refreshNotificationClients() {
  const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
  windows.forEach(client => client.postMessage({ type: 'NOTIFICATIONS_CHANGED' }));
}

self.addEventListener('message', event => {
  if (event.data?.type === 'REFRESH_NOTIFICATION_BADGE') event.waitUntil(refreshNotificationBadge());
});

// Every received push must display a visible notification, especially on iOS.
// Foreground suppression happens on the server before it sends the push.
self.addEventListener('push', event => {
  event.waitUntil((async () => {
    let payload;
    try { payload = event.data?.json(); } catch (_) { /* Use a safe visible fallback. */ }
    const title = payload?.title || 'Haearn notification';
    const options = payload?.options || { body: 'Open Haearn for your latest update.', data: { path: '/' } };
    await self.registration.showNotification(title, options);
    await refreshNotificationBadge(payload?.unread_count);
    await refreshNotificationClients();
  })());
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const data = event.notification.data || {};
    let target = new URL(data.path || '/', self.location.origin);
    if (target.origin !== self.location.origin) target = new URL('/', self.location.origin);
    // Open/focus promptly while the notification-click gesture is still active.
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const existing = windows.find(client => client.url === target.href);
    const opened = existing ? existing.focus() : self.clients.openWindow(target.href);
    try {
      const status = await notificationStatus();
      if (data.kind === 'workout_analysis' && Number.isSafeInteger(data.notification_id) &&
          status.user_id && (!data.user_id || status.user_id === data.user_id)) {
        await fetch(`/notifications/${data.notification_id}/read`, {
          method: 'PATCH', credentials: 'same-origin', cache: 'no-store',
          headers: { 'X-CSRF-Token': status.csrf_token, Accept: 'application/json' }
        });
      }
    } catch (_) { /* Opening the app still works offline; the review acknowledges on resume. */ }
    await opened;
    await refreshNotificationBadge();
    await refreshNotificationClients();
  })());
});

self.addEventListener('notificationclose', event => {
  // Dismissing a banner does not mean its review was read.
  event.waitUntil(refreshNotificationBadge());
});
