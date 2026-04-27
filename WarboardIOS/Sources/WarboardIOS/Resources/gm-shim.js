// Greasemonkey-compatible shims for the WebView host.
//
// The bundled FactionOps + OC Spawn userscripts grant these GM_*
// functions in their headers. Tampermonkey would normally provide
// them; in our raw WebView we have to do it ourselves. Backed by
// localStorage so values survive page navigations + app restarts.
//
// Idempotent — safe to inject on every page load.

(function () {
    if (window.__warboardGMShimInstalled) return;
    window.__warboardGMShimInstalled = true;

    // GM_setValue / GM_getValue — namespace-prefixed localStorage so we
    // don't trample Torn's own storage. Values are JSON-encoded so we
    // round-trip booleans / objects faithfully.
    const NS = 'gm_';
    window.GM_setValue = function (key, value) {
        try { localStorage.setItem(NS + key, JSON.stringify(value)); }
        catch (e) { console.warn('[gm-shim] setValue failed:', e); }
    };
    window.GM_getValue = function (key, defaultValue) {
        try {
            const raw = localStorage.getItem(NS + key);
            if (raw == null) return defaultValue;
            return JSON.parse(raw);
        } catch (e) { return defaultValue; }
    };
    window.GM_deleteValue = function (key) {
        try { localStorage.removeItem(NS + key); } catch (_) {}
    };
    window.GM_listValues = function () {
        const out = [];
        for (let i = 0; i < localStorage.length; i++) {
            const k = localStorage.key(i);
            if (k && k.startsWith(NS)) out.push(k.slice(NS.length));
        }
        return out;
    };

    // GM_addStyle — inject a <style> tag with the given CSS.
    window.GM_addStyle = function (css) {
        const el = document.createElement('style');
        el.type = 'text/css';
        el.appendChild(document.createTextNode(css));
        (document.head || document.documentElement).appendChild(el);
        return el;
    };

    // GM_openInTab — open a URL. WebView equivalent of "new tab" is
    // just navigating in place; we honor the `loadInBackground` flag
    // by no-op'ing if true (we have no concept of background tabs).
    window.GM_openInTab = function (url, options) {
        const opts = (typeof options === 'object' && options) ? options : {};
        if (opts.loadInBackground) return { close: function () {} };
        try { window.location.href = url; } catch (_) {}
        return { close: function () {} };
    };

    // GM_xmlhttpRequest — fetch wrapper that mimics the legacy XHR-style
    // callback interface. Defaults match Tampermonkey:
    //   - no credentials cross-origin (caller opts in via withCredentials)
    //   - same-origin requests follow the browser default
    // The naive previous version forced credentials:'include', which the
    // browser rejects whenever the server returns Access-Control-Allow-
    // Origin:* (the spec forbids credentialed requests against wildcard
    // origins). That manifested as silent network failures on every
    // call to /api/oc/spawn, /api/oc/vault-requests, etc.
    window.GM_xmlhttpRequest = function (details) {
        const method = (details.method || 'GET').toUpperCase();
        const reqUrl = details.url || '';
        let isCrossOrigin = false;
        try {
            const u = new URL(reqUrl, location.href);
            isCrossOrigin = u.origin !== location.origin;
        } catch (_) {}
        const wantCreds = details.withCredentials === true;
        const init = {
            method,
            headers: details.headers || {},
            credentials: details.anonymous
                ? 'omit'
                : (isCrossOrigin
                    ? (wantCreds ? 'include' : 'omit')
                    : 'same-origin'),
            mode: 'cors',
        };
        if (details.data != null && method !== 'GET' && method !== 'HEAD') {
            init.body = details.data;
        }
        const controller = new AbortController();
        init.signal = controller.signal;

        fetch(details.url, init).then(async (res) => {
            const text = await res.text();
            const headersObj = {};
            res.headers.forEach((v, k) => { headersObj[k] = v; });
            const responseLike = {
                readyState: 4,
                status: res.status,
                statusText: res.statusText,
                responseText: text,
                response: text,
                responseHeaders: Object.entries(headersObj)
                    .map(([k, v]) => k + ': ' + v).join('\n'),
                finalUrl: res.url,
            };
            if (typeof details.onload === 'function') details.onload(responseLike);
        }).catch((err) => {
            if (err && err.name === 'AbortError') {
                if (typeof details.onabort === 'function') details.onabort();
                return;
            }
            if (typeof details.onerror === 'function') {
                details.onerror({ status: 0, statusText: String(err), responseText: '' });
            }
        });

        return { abort: function () { controller.abort(); } };
    };

    // unsafeWindow — Tampermonkey returns the page-context window so
    // userscripts can read variables Torn's own JS sets (e.g.
    // `window.torn.faction.scope_balance`). In a WebView there's no
    // sandbox barrier, so window IS the page context. Just alias it.
    window.unsafeWindow = window;

    // ── Native HTTP bridge ─────────────────────────────────────────
    //
    // WebView's Chromium network service rejects our cross-origin
    // requests to tornwar.com from torn.com pages, even with all CORS
    // / CORP / network-security-config relaxations. Same failure mode
    // affects fetch / XHR / WebSocket; only <img> survives because it
    // doesn't go through the CORS-checked path.
    //
    // The userscripts already have a `PDA_httpGet` / `PDA_httpPost`
    // codepath gated on `IS_PDA = typeof window.flutter_inappwebview
    // !== 'undefined'`. By stubbing `flutter_inappwebview` and
    // exposing the PDA-shaped functions backed by Android's native
    // HttpURLConnection (via `WarboardNative` JS bridge), the
    // userscripts route every HTTP call through native code — fully
    // bypassing WebView CORS. Same trick PDA itself uses on iOS.
    if (window.WarboardNative && typeof window.WarboardNative.httpGet === 'function') {
        // NOTE: previously stubbed window.flutter_inappwebview here so
        // the userscripts' `IS_PDA` check would return true and route
        // through PDA_httpGet/PDA_httpPost. That worked but made them
        // render PDA-specific UI ("paste your PDA key…"). Dropped the
        // stub — instead we hook GM_xmlhttpRequest directly below to
        // route cross-origin tornwar.com calls through the native
        // bridge, which works in both the wrapper's desktop and PDA
        // branches and keeps the userscript UI in plain desktop mode.

        // Promise registry — Kotlin posts results back via
        // window.__warboardHttpCallback(id, ok, status, body).
        var __wbCallId = 0;
        window.__warboardHttpCallbacks = {};
        window.__warboardHttpCallback = function (id, ok, status, body) {
            var pending = window.__warboardHttpCallbacks[id];
            if (!pending) return;
            delete window.__warboardHttpCallbacks[id];
            if (ok || (status >= 200 && status < 400)) {
                pending.resolve({
                    status: status,
                    statusText: String(status),
                    responseText: body,
                });
            } else {
                pending.reject(new Error('HTTP ' + status + (body ? ': ' + String(body).slice(0, 120) : '')));
            }
        };

        function nativeRequest(method, url, headers, body) {
            return new Promise(function (resolve, reject) {
                var id = String(++__wbCallId);
                window.__warboardHttpCallbacks[id] = { resolve: resolve, reject: reject };
                try {
                    var headersJson = JSON.stringify(headers || {});
                    if (method === 'GET') {
                        window.WarboardNative.httpGet(url, headersJson, id);
                    } else {
                        window.WarboardNative.httpPost(url, headersJson, String(body || ''), id);
                    }
                } catch (e) {
                    delete window.__warboardHttpCallbacks[id];
                    reject(e);
                }
            });
        }

        window.PDA_httpGet  = function (url, headers)       { return nativeRequest('GET',  url, headers); };
        window.PDA_httpPost = function (url, headers, body) { return nativeRequest('POST', url, headers, body); };

        // Also redirect GM_xmlhttpRequest through the native bridge
        // for the userscript code paths that bypass the wrapper. Same
        // promise → onload/onerror callback shape.
        var origGMReq = window.GM_xmlhttpRequest;
        window.GM_xmlhttpRequest = function (details) {
            var method = (details.method || 'GET').toUpperCase();
            // Only route to native for cross-origin tornwar.com calls;
            // same-origin torn.com requests still go through fetch so
            // cookies and other browser features apply.
            var goNative = false;
            try {
                var u = new URL(details.url, location.href);
                goNative = (u.origin !== location.origin) &&
                    /(^|\.)tornwar\.com$/.test(u.host);
            } catch (_) {}
            if (!goNative) return origGMReq(details);

            var p = (method === 'POST')
                ? window.PDA_httpPost(details.url, details.headers || {}, details.data || '')
                : window.PDA_httpGet(details.url, details.headers || {});
            p.then(function (resp) {
                if (typeof details.onload === 'function') details.onload({
                    readyState: 4, status: resp.status, statusText: resp.statusText,
                    responseText: resp.responseText, response: resp.responseText,
                    responseHeaders: '', finalUrl: details.url,
                });
            }).catch(function (err) {
                if (typeof details.onerror === 'function') details.onerror({
                    status: 0, statusText: String(err && err.message || err), responseText: '',
                });
            });
            return { abort: function () { /* native call already in flight; no cancel surface yet */ } };
        };

        nlog('native HTTP bridge installed → cross-origin via Kotlin');
    } else {
        nlog('WarboardNative bridge NOT present — falling back to fetch shim');
    }

    console.info('[gm-shim] installed');

    // Bridge to native logcat. WarboardNative is added by MainActivity's
    // addJavascriptInterface in the Android wrapper; absent in plain
    // Tampermonkey/Greasemonkey contexts so we feature-detect.
    function nlog(msg) {
        try { console.info('[gm-shim]', msg); } catch (_) {}
        try {
            if (window.WarboardNative && typeof window.WarboardNative.log === 'function') {
                window.WarboardNative.log(String(msg));
            }
        } catch (_) {}
    }

    nlog('shim installed at ' + location.href.slice(0, 80));

    // Visible corner badge — gives the user direct proof the shim is
    // running even without server-log access. Auto-dismisses after a
    // few seconds so it doesn't clutter the page long-term.
    function showBadge(text, color) {
        try {
            if (!document.body) {
                document.addEventListener('DOMContentLoaded', function () { showBadge(text, color); });
                return;
            }
            var prev = document.getElementById('warboard-shim-badge');
            if (prev) prev.remove();
            var el = document.createElement('div');
            el.id = 'warboard-shim-badge';
            el.textContent = text;
            el.style.cssText = 'position:fixed;bottom:8px;right:8px;z-index:2147483647;'
                + 'padding:4px 8px;border-radius:4px;font:11px monospace;'
                + 'background:' + (color || '#2d6a4f') + ';color:#fff;'
                + 'box-shadow:0 1px 4px rgba(0,0,0,.4);pointer-events:none;';
            document.body.appendChild(el);
            setTimeout(function () { try { el.remove(); } catch (_) {} }, 8000);
        } catch (e) { nlog('badge err: ' + e.message); }
    }

    // Self-test with verbose error capture. The badge surfaces the
    // ACTUAL error string (not just ✓/✗) so we can diagnose without
    // logcat. Ordering: same-origin fetch first — if even THAT fails
    // we know it's not CORS / CORP / cross-origin specifics, the
    // problem is at fetch/XHR level entirely.
    function selfTest() {
        var sameOrigin  = location.origin + '/?warboard_probe=1&t=' + Date.now();
        var crossOrigin = 'https://tornwar.com/api/debug/shim-ping?at='
            + encodeURIComponent(location.href.slice(0, 80)) + '&t=' + Date.now();

        var lines = ['origin=' + (location.origin || 'NULL')];

        function flush() {
            var el = document.getElementById('warboard-shim-log');
            if (!el) {
                if (!document.body) {
                    document.addEventListener('DOMContentLoaded', flush);
                    return;
                }
                el = document.createElement('div');
                el.id = 'warboard-shim-log';
                el.style.cssText = 'position:fixed;bottom:8px;right:8px;left:8px;z-index:2147483647;'
                    + 'padding:6px 8px;border-radius:4px;font:10px/1.3 monospace;'
                    + 'background:rgba(20,20,30,0.92);color:#fff;'
                    + 'max-height:50vh;overflow:auto;white-space:pre-wrap;'
                    + 'border:1px solid #444;'
                    // pointer-events:none so taps pass through to the
                    // FactionOps gear / refresh / Send buttons that sit
                    // underneath. The auto-dismiss timeout still hides
                    // it, but in the meantime the user shouldn't be
                    // blocked from interacting with anything.
                    + 'pointer-events:none;';
                document.body.appendChild(el);
                // Auto-hide after 4s — the user can tap to dismiss
                // sooner. Diagnostic noise shouldn't sit on every Torn
                // page forever now that the bridge is the actual code
                // path; the raw probes only confirm what the WebView's
                // network stack can do, not what the userscripts use.
                setTimeout(function () { try { el.remove(); } catch (_) {} }, 4000);
            }
            el.textContent = lines.join('\n');
        }

        function note(s) { lines.push(s); flush(); nlog(s); }

        function probeFetch(url, label) {
            try {
                fetch(url, { method: 'GET', mode: 'cors', credentials: 'omit' })
                    .then(function (r) { note('fetch ' + label + ' → status ' + r.status); })
                    .catch(function (e) { note('fetch ' + label + ' THREW: ' + (e && (e.message || e))); });
            } catch (e) {
                note('fetch ' + label + ' SYNC THREW: ' + e.message);
            }
        }

        function probeXhr(url, label) {
            try {
                var xhr = new XMLHttpRequest();
                xhr.open('GET', url, true);
                xhr.onload  = function () { note('xhr ' + label + ' → status ' + xhr.status); };
                xhr.onerror = function () { note('xhr ' + label + ' ERROR (status=' + xhr.status + ')'); };
                xhr.send();
            } catch (e) {
                note('xhr ' + label + ' SYNC THREW: ' + e.message);
            }
        }

        probeFetch(sameOrigin,  'same');
        probeXhr(  sameOrigin,  'same');
        probeFetch(crossOrigin, 'cross');
        probeXhr(  crossOrigin, 'cross');

        // Image probe — bypasses CORS entirely. If this loads, the
        // WebView can reach tornwar.com at the network layer. If it
        // ALSO fails, the block is at TLS/transport level.
        try {
            var img = new Image();
            img.onload  = function () { note('img cross → loaded ' + img.naturalWidth + 'x' + img.naturalHeight); };
            img.onerror = function () { note('img cross → ERROR'); };
            img.src = 'https://tornwar.com/icon-192.png?t=' + Date.now();
        } catch (e) { note('img cross threw: ' + e.message); }

        // WebSocket probe — pure-TCP path independent of fetch.
        try {
            var ws = new WebSocket('wss://tornwar.com/socket.io/?EIO=4&transport=websocket');
            ws.onopen  = function () { note('ws → OPEN'); ws.close(); };
            ws.onerror = function () { note('ws → ERROR'); };
            setTimeout(function () { try { ws.close(); } catch (_) {} }, 4000);
        } catch (e) { note('ws threw: ' + e.message); }

        flush();
    }

    // Defer slightly so DOM is ready.
    setTimeout(selfTest, 1000);
})();
