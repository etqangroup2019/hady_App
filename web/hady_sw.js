/* عامل الخدمة لتطبيق هَدْي
 * 1) يستقبل Push من الخادم في موعد كل تنبيه ويعرضه حتى والتطبيق مغلق.
 * 2) يخزّن الملفات ليعمل التطبيق دون إنترنت (الشبكة أولاً ثم التخزين).
 *
 * الخادم يرسل Push فارغاً (بلا حمولة مشفّرة)، والعامل يقرأ تفاصيل التنبيه
 * (العنوان والنص) من IndexedDB حيث حفظها التطبيق عند آخر مزامنة.
 */
'use strict';

var CACHE = 'hady-v1';
var CACHEABLE_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];

// نافذة قبول التنبيه: يُعرض إن كان موعده بين (الآن − 15 دقيقة) و(الآن + دقيقة).
var LATE_SECS = 900;
var EARLY_SECS = 60;

// ───────────── IndexedDB (مشترك مع الصفحة) ─────────────
function db() {
  return new Promise(function (res, rej) {
    var r = indexedDB.open('hady', 1);
    r.onupgradeneeded = function () { r.result.createObjectStore('kv'); };
    r.onsuccess = function () { res(r.result); };
    r.onerror = function () { rej(r.error); };
  });
}
function kvGet(key) {
  return db().then(function (d) {
    return new Promise(function (res, rej) {
      var q = d.transaction('kv', 'readonly').objectStore('kv').get(key);
      q.onsuccess = function () { res(q.result === undefined ? null : q.result); };
      q.onerror = function () { rej(q.error); };
    });
  });
}
function kvSet(key, val) {
  return db().then(function (d) {
    return new Promise(function (res, rej) {
      var tx = d.transaction('kv', 'readwrite');
      tx.objectStore('kv').put(val, key);
      tx.oncomplete = function () { res(); };
      tx.onerror = function () { rej(tx.error); };
    });
  });
}

// ───────────── اختيار التنبيهات المستحقة (دالة نقية قابلة للاختبار) ─────────────
function pickDue(items, shownSet, nowSecs) {
  var out = [];
  for (var i = 0; i < (items || []).length; i++) {
    var it = items[i];
    if (!it || typeof it.t !== 'number') continue;
    if (shownSet.has(it.k)) continue;
    if (it.t <= nowSecs + EARLY_SECS && it.t >= nowSecs - LATE_SECS) out.push(it);
  }
  out.sort(function (a, b) { return a.t - b.t; });
  return out;
}

function vibrateFor(type) {
  switch (type) {
    case 'adhan': return [300, 150, 300, 150, 300];
    case 'iqama': return [200, 100, 200];
    case 'pre': return [150];
    default: return [200, 100, 200];
  }
}

function optionsFor(it) {
  if (it.ty === 'status') {
    return {
      body: it.b || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      lang: 'ar',
      dir: 'rtl',
      tag: 'hady-status',
      renotify: false,
      silent: true,
      requireInteraction: true,
      data: { k: it.k, ty: 'status' }
    };
  }
  return {
    body: it.b || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    lang: 'ar',
    dir: 'rtl',
    tag: it.k,
    renotify: false,
    timestamp: it.t * 1000,
    vibrate: vibrateFor(it.ty),
    requireInteraction: it.ty === 'adhan' || it.ty === 'iqama',
    data: { k: it.k, ty: it.ty }
  };
}

function handlePush() {
  var now = Math.floor(Date.now() / 1000);
  return Promise.all([kvGet('sched'), kvGet('shown')]).then(function (r) {
    var items = r[0] || [];
    var shown = new Set(r[1] || []);
    var due = pickDue(items, shown, now);
    var jobs = [];
    due.forEach(function (it) {
      shown.add(it.k);
      jobs.push(self.registration.showNotification(it.ti || 'هَدْي', optionsFor(it)));
    });
    if (!due.length) {
      // المتصفح يشترط إظهار تنبيه عند كل Push؛ نعرض إشعاراً خفيفاً ونغلقه بسرعة.
      jobs.push(
        self.registration
          .showNotification('هَدْي', {
            body: 'تذكير',
            icon: 'icons/Icon-192.png',
            tag: 'hady-misc',
            silent: true,
            lang: 'ar',
            dir: 'rtl'
          })
          .then(function () {
            return new Promise(function (res) { setTimeout(res, 3000); });
          })
          .then(function () { return self.registration.getNotifications({ tag: 'hady-misc' }); })
          .then(function (list) { list.forEach(function (n) { n.close(); }); })
      );
    }
    var keep = Array.from(shown).slice(-300);
    jobs.push(kvSet('shown', keep));
    return Promise.all(jobs);
  });
}

self.addEventListener('push', function (e) {
  e.waitUntil(handlePush());
});

self.addEventListener('notificationclick', function (e) {
  // إشعار الحالة الدائم يبقى في الدرج بعد النقر عليه.
  if (!(e.notification.data && e.notification.data.ty === 'status')) e.notification.close();
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (all) {
      for (var i = 0; i < all.length; i++) {
        if ('focus' in all[i]) return all[i].focus();
      }
      return self.clients.openWindow(self.registration.scope);
    })
  );
});

// إن جدّد المتصفح الاشتراك (يحدث أحياناً) نعيد التسجيل لدى الخادم تلقائياً.
self.addEventListener('pushsubscriptionchange', function (e) {
  e.waitUntil(
    kvGet('cfg').then(function (cfg) {
      if (!cfg || !cfg.pushUrl || !cfg.publicKey) return;
      var raw = atob(cfg.publicKey.replace(/-/g, '+').replace(/_/g, '/'));
      var key = new Uint8Array(raw.length);
      for (var i = 0; i < raw.length; i++) key[i] = raw.charCodeAt(i);
      return self.registration.pushManager
        .subscribe({ userVisibleOnly: true, applicationServerKey: key })
        .then(function (sub) {
          return kvGet('sched').then(function (items) {
            return fetch(cfg.pushUrl + '/subscribe', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ subscription: sub.toJSON(), times: (items || []).map(function (x) { return x.t; }) })
            });
          });
        });
    })
  );
});

// ───────────── التخزين للعمل دون إنترنت ─────────────
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  var same = url.origin === self.location.origin;
  if (!same && CACHEABLE_HOSTS.indexOf(url.hostname) < 0) return;

  e.respondWith(
    fetch(req)
      .then(function (res) {
        if (res && res.status === 200) {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { return c.put(req, copy); }).catch(function () {});
        }
        return res;
      })
      .catch(function () {
        return caches.match(req).then(function (hit) {
          if (hit) return hit;
          if (req.mode === 'navigate') {
            return caches.match(self.registration.scope).then(function (idx) {
              return idx || caches.match(new URL('index.html', self.registration.scope).href);
            });
          }
          return Response.error();
        });
      })
  );
});

if (typeof module !== 'undefined') module.exports = { pickDue: pickDue };
