import Foundation

/// Injected into the hidden background host only. ReTorn's `background.js`
/// `fetch()`es `api.torn.com` and `www.tornstats.com` directly — cross-origin
/// from the background page, which CORS would block. Override `fetch` so those
/// two hosts route through the native `webextBridge` (`apiFetch`), which does a
/// real URLSession request and returns the body. All other fetches (e.g.
/// same-origin `webext://retorn/files/...` defaults) pass through untouched.
enum WebExtBgFetchJS {
    static let source = #"""
    (function () {
      var _fetch = window.fetch.bind(window);
      window.fetch = function (input, init) {
        var url = (typeof input === 'string') ? input : (input && input.url);
        if (url && (/^https:\/\/api\.torn\.com\//.test(url) ||
                    /^https:\/\/www\.tornstats\.com\//.test(url))) {
          return window.webkit.messageHandlers.webextBridge
            .postMessage({ kind: 'apiFetch', url: url })
            .then(function (r) {
              return new Response((r && r.body) || '', {
                status: (r && r.status) || 200,
                headers: { 'Content-Type': 'application/json' }
              });
            });
        }
        return _fetch(input, init);
      };
    })();
    """#
}
