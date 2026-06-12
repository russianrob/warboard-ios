import Foundation

/// The injected `window.browser` (+ `chrome` alias) WebExtension API shim.
///
/// Injected first into both the page content world (for the extension's content
/// scripts) and the hidden background host (for `background.js`). Async methods
/// round-trip through the native `webextBridge` message handler — a
/// `WKScriptMessageHandlerWithReply`, so `postMessage(...)` returns a promise
/// the shim resolves the caller's callback from. Events flow native→JS via
/// `window.__webext_emit`; the background host runs message handlers via
/// `window.__webext_handleMessage`.
enum WebExtShimJS {
    static let source = #"""
    (function () {
      if (window.browser && window.browser.__wbExt) return;

      function post(m) {
        try { return window.webkit.messageHandlers.webextBridge.postMessage(m); }
        catch (e) { return Promise.reject(e); }
      }
      // ReTorn uses callback style; we also return the promise.
      function cbWrap(promise, cb) {
        if (typeof cb === 'function') {
          promise.then(function (r) { try { cb(r); } catch (e) {} },
                       function () { try { cb(undefined); } catch (e) {} });
        }
        return promise;
      }

      // ---- event registry (native -> JS via window.__webext_emit) ----
      var listeners = { message: [], storageChanged: [], alarm: [], notifClicked: [], installed: [] };
      function event(bucket) {
        return {
          addListener: function (fn) { if (typeof fn === 'function') listeners[bucket].push(fn); },
          removeListener: function (fn) { var i = listeners[bucket].indexOf(fn); if (i >= 0) listeners[bucket].splice(i, 1); },
          hasListener: function (fn) { return listeners[bucket].indexOf(fn) >= 0; }
        };
      }
      window.__webext_emit = function (type, a, b, c) {
        var arr = listeners[type] || [];
        for (var i = 0; i < arr.length; i++) { try { arr[i](a, b, c); } catch (e) {} }
      };

      // Native fires this once on first run / version change so the background's
      // onInstalled handler seeds default settings+features into storage.
      window.__webext_fireInstalled = function (details) {
        var arr = listeners.installed;
        for (var i = 0; i < arr.length; i++) { try { arr[i](details); } catch (e) {} }
      };

      // Background host: run onMessage listeners for a relayed message and
      // resolve the reply, honoring the `return true` deferred-async pattern.
      window.__webext_handleMessage = function (msg, sender) {
        return new Promise(function (resolve) {
          var arr = listeners.message, settled = false, async = false;
          function sendResponse(r) { if (!settled) { settled = true; resolve(r); } }
          for (var i = 0; i < arr.length; i++) {
            try {
              var ret = arr[i](msg, sender || {}, sendResponse);
              if (ret === true) async = true;
              else if (ret && typeof ret.then === 'function') { async = true; ret.then(sendResponse); }
            } catch (e) {}
          }
          if (!async) sendResponse(undefined);
        });
      };

      function storageArea(area) {
        return {
          get: function (keys, cb) { return cbWrap(post({ kind: 'storage', area: area, op: 'get', keys: keys === undefined ? null : keys }), cb); },
          set: function (obj, cb) { return cbWrap(post({ kind: 'storage', area: area, op: 'set', items: obj }), cb); },
          remove: function (keys, cb) { return cbWrap(post({ kind: 'storage', area: area, op: 'remove', keys: keys }), cb); },
          clear: function (cb) { return cbWrap(post({ kind: 'storage', area: area, op: 'clear' }), cb); },
          onChanged: event('storageChanged')
        };
      }

      var api = {
        __wbExt: true,
        runtime: {
          id: 'retorn-webext',
          lastError: null,
          sendMessage: function (msg, cb) { return cbWrap(post({ kind: 'sendMessage', message: msg }), cb); },
          onMessage: event('message'),
          onInstalled: event('installed'),
          onStartup: { addListener: function () {} },
          connect: function () { return { onMessage: { addListener: function () {} }, postMessage: function () {}, disconnect: function () {} }; },
          getURL: function (p) { return 'webext://retorn/' + String(p || '').replace(/^\//, ''); },
          getManifest: function () { return { manifest_version: 3, version: (window.__webext_version || '0') }; },
          openOptionsPage: function (cb) { post({ kind: 'openExtPage', page: 'options' }); if (typeof cb === 'function') cb(); }
        },
        storage: {
          local: storageArea('local'),
          sync: storageArea('sync'),
          session: storageArea('session'),
          onChanged: event('storageChanged')
        },
        alarms: {
          create: function (name, info) { post({ kind: 'alarms', op: 'create', name: name, info: info }); },
          get: function (name, cb) { return cbWrap(post({ kind: 'alarms', op: 'get', name: name }), cb); },
          clear: function (name, cb) { return cbWrap(post({ kind: 'alarms', op: 'clear', name: name }), cb); },
          clearAll: function (cb) { return cbWrap(post({ kind: 'alarms', op: 'clearAll' }), cb); },
          onAlarm: event('alarm')
        },
        notifications: {
          create: function (id, opts, cb) { return cbWrap(post({ kind: 'notifications', op: 'create', id: id, opts: opts }), cb); },
          clear: function (id, cb) { return cbWrap(post({ kind: 'notifications', op: 'clear', id: id }), cb); },
          onClicked: event('notifClicked'),
          onButtonClicked: event('notifClicked')
        },
        tabs: {
          create: function (props, cb) { return cbWrap(post({ kind: 'tabs', op: 'create', props: props }), cb); },
          query: function (q, cb) { return cbWrap(post({ kind: 'tabs', op: 'query', query: q }), cb); },
          update: function (id, props, cb) { return cbWrap(post({ kind: 'tabs', op: 'update', id: id, props: props }), cb); },
          sendMessage: function (id, msg, cb) { return cbWrap(post({ kind: 'tabs', op: 'sendMessage', id: id, message: msg }), cb); },
          onUpdated: { addListener: function () {} },
          onActivated: { addListener: function () {} }
        },
        action: {
          setBadgeText: function (d, cb) { post({ kind: 'action', op: 'badgeText', details: d }); if (cb) cb(); },
          setBadgeBackgroundColor: function (d, cb) { if (cb) cb(); },
          setIcon: function (d, cb) { if (cb) cb(); },
          setPopup: function (d, cb) { if (cb) cb(); },
          setTitle: function (d, cb) { if (cb) cb(); },
          onClicked: { addListener: function () {} }
        },
        i18n: { getMessage: function (k) { return k; }, getUILanguage: function () { return 'en'; } },
        permissions: {
          contains: function (p, cb) { return cbWrap(Promise.resolve(true), cb); },
          request: function (p, cb) { return cbWrap(Promise.resolve(true), cb); },
          getAll: function (cb) { return cbWrap(Promise.resolve({ permissions: [], origins: [] }), cb); },
          onAdded: { addListener: function () {} },
          onRemoved: { addListener: function () {} }
        }
      };
      api.browserAction = api.action;
      window.browser = api;
      window.chrome = api;
    })();
    """#
}
