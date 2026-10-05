// جسر الإشعارات والأصوات والموقع وتنبيهات الخلفية — تستدعيه Dart عبر lib/bridge.dart
(function () {
  'use strict';

  // ───────────── تخزين مشترك مع عامل الخدمة (IndexedDB: hady/kv) ─────────────
  function hdb() {
    return new Promise(function (res, rej) {
      var r = indexedDB.open('hady', 1);
      r.onupgradeneeded = function () { r.result.createObjectStore('kv'); };
      r.onsuccess = function () { res(r.result); };
      r.onerror = function () { rej(r.error); };
    });
  }
  function kvGet(key) {
    return hdb().then(function (d) {
      return new Promise(function (res, rej) {
        var q = d.transaction('kv', 'readonly').objectStore('kv').get(key);
        q.onsuccess = function () { res(q.result === undefined ? null : q.result); };
        q.onerror = function () { rej(q.error); };
      });
    });
  }
  function kvSet(key, val) {
    return hdb().then(function (d) {
      return new Promise(function (res, rej) {
        var tx = d.transaction('kv', 'readwrite');
        tx.objectStore('kv').put(val, key);
        tx.oncomplete = function () { res(); };
        tx.onerror = function () { rej(tx.error); };
      });
    });
  }
  function isShown(k) {
    if (!k) return Promise.resolve(false);
    return kvGet('shown').then(function (l) { return (l || []).indexOf(k) >= 0; }, function () { return false; });
  }
  function markShown(k) {
    if (!k) return Promise.resolve();
    return kvGet('shown').then(function (l) {
      l = l || [];
      if (l.indexOf(k) < 0) l.push(k);
      return kvSet('shown', l.slice(-300));
    }).catch(function () {});
  }

  // ───────────── عامل الخدمة ─────────────
  function swUrl() { return new URL('hady_sw.js', document.baseURI).href; }

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register(swUrl()).catch(function (e) {
        console.warn('تعذّر تسجيل عامل الخدمة', e);
      });
    });
  }

  function readyReg() {
    if (!('serviceWorker' in navigator)) return Promise.reject(new Error('unsupported'));
    return Promise.race([
      navigator.serviceWorker.ready,
      new Promise(function (_, rej) { setTimeout(function () { rej(new Error('sw-timeout')); }, 12000); })
    ]);
  }

  // ───────────── الصوت ─────────────
  var ctx = null;

  function audioCtx() {
    if (!ctx) {
      var C = window.AudioContext || window.webkitAudioContext;
      if (C) ctx = new C();
    }
    if (ctx && ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  // المتصفحات تمنع الصوت قبل أول تفاعل؛ نفتحه عند أول لمسة.
  ['pointerdown', 'keydown', 'touchstart'].forEach(function (ev) {
    window.addEventListener(ev, function () { audioCtx(); }, { once: true, passive: true });
  });

  function tone(c, freq, start, dur, vol, type) {
    var o = c.createOscillator();
    var g = c.createGain();
    o.type = type || 'sine';
    o.frequency.value = freq;
    g.gain.setValueAtTime(0.0001, start);
    g.gain.exponentialRampToValueAtTime(Math.max(vol, 0.0002), start + 0.03);
    g.gain.exponentialRampToValueAtTime(0.0001, start + dur);
    o.connect(g);
    g.connect(c.destination);
    o.start(start);
    o.stop(start + dur + 0.05);
  }

  var SOUNDS = {
    bell: function (c, t, v) {
      tone(c, 880, t, 2.0, v * 0.5);
      tone(c, 1320, t, 1.4, v * 0.25);
      tone(c, 2200, t, 0.7, v * 0.1);
    },
    chime: function (c, t, v) {
      [659.25, 783.99, 987.77].forEach(function (f, i) { tone(c, f, t + i * 0.2, 1.3, v * 0.4); });
    },
    drop: function (c, t, v) {
      var o = c.createOscillator();
      var g = c.createGain();
      o.type = 'sine';
      o.frequency.setValueAtTime(1100, t);
      o.frequency.exponentialRampToValueAtTime(320, t + 0.35);
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(Math.max(v * 0.5, 0.0002), t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.6);
      o.connect(g);
      g.connect(c.destination);
      o.start(t);
      o.stop(t + 0.7);
    },
    harp: function (c, t, v) {
      [392, 440, 523.25, 587.33, 659.25, 783.99].forEach(function (f, i) {
        tone(c, f, t + i * 0.16, 1.4, v * 0.3, 'triangle');
      });
    },
    tone: function (c, t, v) {
      [293.66, 349.23, 440, 349.23, 293.66].forEach(function (f, i) {
        tone(c, f, t + i * 0.7, 1.6, v * 0.3, 'triangle');
      });
    },
    double: function (c, t, v) {
      tone(c, 740, t, 0.35, v * 0.45);
      tone(c, 740, t + 0.5, 0.35, v * 0.45);
    }
  };

  // ───────────── تخزين الملفات الصوتية المخصصة (IndexedDB) ─────────────
  function idb() {
    return new Promise(function (res, rej) {
      var r = indexedDB.open('sunnah-sounds', 1);
      r.onupgradeneeded = function () { r.result.createObjectStore('s'); };
      r.onsuccess = function () { res(r.result); };
      r.onerror = function () { rej(r.error); };
    });
  }

  function putBlob(key, blob) {
    return idb().then(function (db) {
      return new Promise(function (res, rej) {
        var tx = db.transaction('s', 'readwrite');
        tx.objectStore('s').put(blob, key);
        tx.oncomplete = function () { res(); };
        tx.onerror = function () { rej(tx.error); };
      });
    });
  }

  function getBlob(key) {
    return idb().then(function (db) {
      return new Promise(function (res, rej) {
        var rq = db.transaction('s', 'readonly').objectStore('s').get(key);
        rq.onsuccess = function () { res(rq.result || null); };
        rq.onerror = function () { rej(rq.error); };
      });
    });
  }

  function pickAudio(type) {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = 'audio/*';
      input.style.display = 'none';
      document.body.appendChild(input);
      var done = false;
      function finish(v) {
        if (done) return;
        done = true;
        resolve(v);
        setTimeout(function () { input.remove(); }, 0);
      }
      input.addEventListener('change', function () {
        var f = input.files && input.files[0];
        if (!f) return finish('');
        putBlob('sound:' + type, f).then(function () { finish(f.name); }, function () { finish(''); });
      });
      input.addEventListener('cancel', function () { finish(''); });
      input.click();
    });
  }

  function hasCustom(type) {
    return getBlob('sound:' + type).then(function (b) { return !!b; }, function () { return false; });
  }

  // ───────────── التشغيل ─────────────
  var currentAudio = null;

  function play(sound, type, volume) {
    if (!sound || sound === 'none') return;
    var v = Math.min(1, Math.max(0, Number(volume) || 0.8));

    if (sound === 'custom') {
      getBlob('sound:' + type).then(function (blob) {
        if (!blob) { SOUNDS.chime(audioCtx(), audioCtx().currentTime + 0.02, v); return; }
        if (currentAudio) { currentAudio.pause(); }
        var url = URL.createObjectURL(blob);
        var a = new Audio(url);
        a.volume = v;
        a.onended = function () { URL.revokeObjectURL(url); };
        currentAudio = a;
        a.play().catch(function () {});
      }).catch(function () {});
      return;
    }

    var c = audioCtx();
    var fn = SOUNDS[sound] || SOUNDS.chime;
    if (c) fn(c, c.currentTime + 0.02, v);
  }

  // ───────────── الإشعارات (والتطبيق مفتوح) ─────────────
  function permission() {
    return ('Notification' in window) ? Notification.permission : 'unsupported';
  }

  function requestPermission() {
    if (!('Notification' in window)) return Promise.resolve('unsupported');
    return Notification.requestPermission().then(function (p) { return p; });
  }

  function vibrateFor(type) {
    switch (type) {
      case 'adhan': return [300, 150, 300, 150, 300];
      case 'iqama': return [200, 100, 200];
      case 'pre': return [150];
      default: return [200, 100, 200];
    }
  }

  function showSystem(title, body, sound, type, key) {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;

    // إن كان الصوت يعمل من صفحتنا نكتم صوت النظام لتفادي التكرار.
    var ours = sound !== 'none' && ctx && ctx.state === 'running';
    var silent = !!ours || sound === 'none';
    var opts = {
      body: body,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      lang: 'ar',
      dir: 'rtl',
      tag: key || (type + ':' + title),
      renotify: false,
      silent: silent,
      requireInteraction: type === 'adhan' || type === 'iqama'
    };
    // مهم: المتصفح يرمي TypeError إن اجتمع (silent: true) مع (vibrate)، فلا نضيف الاهتزاز للصامت.
    if (!silent) opts.vibrate = vibrateFor(type);

    // عامل الخدمة أولاً (الوحيد المسموح على الجوال)، وإلا الإشعار العادي، وأخيراً أبسط خيارات ممكنة.
    var viaSW = (navigator.serviceWorker && navigator.serviceWorker.getRegistration)
      ? navigator.serviceWorker.getRegistration().then(function (reg) {
          if (!reg) throw new Error('no-sw');
          return reg.showNotification(title, opts);
        })
      : Promise.reject(new Error('no-sw'));
    viaSW.catch(function (err) {
      console.warn('showNotification via SW failed:', err && err.message);
      try { new Notification(title, opts); }
      catch (e) {
        try { new Notification(title, { body: body, tag: opts.tag }); }
        catch (e2) { console.warn('Notification failed:', e2 && e2.message); }
      }
    });
  }

  // key: معرّف التنبيه؛ يمنع تكرار العرض إن سبقه عامل الخدمة (Push) أو العكس.
  function notify(title, body, sound, type, volume, key) {
    isShown(key).then(function (already) {
      play(sound, type, volume);
      if (already) return;
      markShown(key);
      showSystem(title, body, sound, type, key);
    });
  }

  // ───────────── تنبيهات الخلفية (Web Push) ─────────────
  function cfgUrl() {
    var u = (window.HadyConfig && window.HadyConfig.pushUrl) || '';
    return String(u).replace(/\/+$/, '');
  }

  function isIOS() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }

  function isStandalone() {
    return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
      window.navigator.standalone === true;
  }

  function b64urlToBytes(s) {
    var p = s.replace(/-/g, '+').replace(/_/g, '/');
    while (p.length % 4) p += '=';
    var raw = atob(p);
    var out = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  function sameKey(a, b) {
    if (!a || !b || a.byteLength !== b.byteLength) return false;
    var x = new Uint8Array(a), y = new Uint8Array(b);
    for (var i = 0; i < x.length; i++) if (x[i] !== y[i]) return false;
    return true;
  }

  function currentSub() {
    return navigator.serviceWorker.getRegistration().then(function (reg) {
      return reg ? reg.pushManager.getSubscription() : null;
    });
  }

  function pushStatus() {
    var st = {
      supported: !!(('serviceWorker' in navigator) && ('PushManager' in window) && ('Notification' in window)),
      configured: !!cfgUrl(),
      permission: permission(),
      subscribed: false,
      standalone: isStandalone(),
      ios: isIOS(),
      count: 0,
      lastSync: 0
    };
    var steps = [];
    if (st.supported) {
      steps.push(currentSub().then(function (s) { st.subscribed = !!s; }).catch(function () {}));
    }
    steps.push(kvGet('sched').then(function (l) { st.count = (l || []).length; }).catch(function () {}));
    steps.push(kvGet('lastSync').then(function (t) { st.lastSync = t || 0; }).catch(function () {}));
    return Promise.all(steps).then(function () { return JSON.stringify(st); });
  }

  function postJson(path, body) {
    return fetch(cfgUrl() + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
  }

  function syncSchedule(json) {
    var items = JSON.parse(json);
    return kvSet('sched', items).then(function () {
      if (!cfgUrl() || !('serviceWorker' in navigator)) return 'local';
      return currentSub().then(function (sub) {
        if (!sub) return 'local';
        return postJson('/subscribe', {
          subscription: sub.toJSON(),
          times: items.map(function (i) { return i.t; })
        }).then(function (res) {
          if (!res.ok) throw new Error('server-' + res.status);
          return kvSet('lastSync', Date.now()).then(function () { return 'synced'; });
        });
      });
    });
  }

  function enablePush(json) {
    if (!cfgUrl()) return Promise.reject(new Error('not-configured'));
    return requestPermission().then(function (perm) {
      if (perm !== 'granted') throw new Error('permission-' + perm);
      return Promise.all([
        readyReg(),
        fetch(cfgUrl() + '/config').then(function (r) {
          if (!r.ok) throw new Error('server-' + r.status);
          return r.json();
        })
      ]);
    }).then(function (r) {
      var reg = r[0];
      var conf = r[1];
      var key = b64urlToBytes(conf.publicKey);
      return reg.pushManager.getSubscription().then(function (sub) {
        if (sub && !sameKey(sub.options && sub.options.applicationServerKey, key.buffer)) {
          return sub.unsubscribe().then(function () { return null; });
        }
        return sub;
      }).then(function (sub) {
        return sub || reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
      }).then(function () {
        return kvSet('cfg', { pushUrl: cfgUrl(), publicKey: conf.publicKey });
      });
    }).then(function () { return syncSchedule(json); })
      .then(function () { return 'ok'; });
  }

  function disablePush() {
    return currentSub().then(function (sub) {
      if (!sub) return 'ok';
      var ep = sub.endpoint;
      var tell = cfgUrl() ? postJson('/unsubscribe', { endpoint: ep }).catch(function () {}) : Promise.resolve();
      return tell.then(function () { return sub.unsubscribe(); }).then(function () { return 'ok'; });
    }).then(function () { return kvSet('sched', []); }).then(function () { return 'ok'; });
  }

  // ───────────── إشعار الحالة الدائم (الصلاة القادمة والإقامة) ─────────────
  // يُعرض بصمت وبنفس الوسم دائماً فيُستبدل ولا يتكرر. العدّ التنازلي الحي لا يُعرض إلا والتطبيق ظاهر؛
  // وعند إخفائه نعرض النص الثابت (الأوقات المطلقة) حتى لا يبقى رقم متبقٍ قديم في الدرج.
  var statusState = null;

  function showStatus() {
    if (!statusState || permission() !== 'granted') return Promise.resolve();
    var hidden = typeof document !== 'undefined' && document.hidden;
    return readyReg().then(function (reg) {
      return reg.showNotification(statusState.title, {
        body: hidden ? statusState.stat : statusState.live,
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-192.png',
        lang: 'ar',
        dir: 'rtl',
        tag: 'hady-status',
        renotify: false,
        silent: true,
        requireInteraction: true,
        data: { ty: 'status' }
      });
    }).catch(function () {});
  }

  function setStatus(title, live, stat) {
    statusState = { title: title, live: live, stat: stat };
    return showStatus().then(function () { return 'ok'; });
  }

  function clearStatus() {
    statusState = null;
    return readyReg().then(function (reg) {
      return reg.getNotifications({ tag: 'hady-status' });
    }).then(function (list) {
      list.forEach(function (n) { n.close(); });
      return 'ok';
    }).catch(function () { return 'ok'; });
  }

  if (typeof document !== 'undefined') {
    document.addEventListener('visibilitychange', function () { showStatus(); });
  }
  window.addEventListener('pagehide', function () { showStatus(); });

  // ───────────── الموقع ─────────────
  function locate() {
    return new Promise(function (resolve, reject) {
      if (!navigator.geolocation) return reject(new Error('unsupported'));
      navigator.geolocation.getCurrentPosition(
        function (pos) {
          resolve(JSON.stringify({ lat: pos.coords.latitude, lon: pos.coords.longitude }));
        },
        function (err) { reject(new Error(err && err.message ? err.message : 'denied')); },
        { enableHighAccuracy: false, timeout: 15000, maximumAge: 600000 }
      );
    });
  }

  window.SunnahBridge = {
    permission: permission,
    requestPermission: requestPermission,
    notify: notify,
    play: play,
    locate: locate,
    pickAudio: pickAudio,
    hasCustom: hasCustom,
    pushStatus: pushStatus,
    enablePush: enablePush,
    disablePush: disablePush,
    syncSchedule: syncSchedule,
    setStatus: setStatus,
    clearStatus: clearStatus
  };
})();
