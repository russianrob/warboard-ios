(function () {
  "use strict";

  var ctx = (typeof __WB_SCRIPT_CONTEXT__ !== "undefined")
    ? __WB_SCRIPT_CONTEXT__ : { scriptId: "", info: {}, store: {} };

  var SCRIPT_ID = ctx.scriptId;
  var store = ctx.store || {};
  var menuCommands = [];
  var bridge = (window.webkit
    && window.webkit.messageHandlers
    && window.webkit.messageHandlers.gmBridge) || null;

  function post(action, payload) {
    if (!bridge) {
      return Promise.reject(new Error("GM bridge unavailable"));
    }
    return bridge.postMessage({
      scriptId: SCRIPT_ID,
      action: action,
      payload: payload || {}
    });
  }

  function GM_getValue(key, defaultValue) {
    return Object.prototype.hasOwnProperty.call(store, key)
      ? store[key]
      : defaultValue;
  }
  function GM_listValues() {
    return Object.keys(store);
  }

  function GM_setValue(key, value) {
    store[key] = value;
    return post("setValue", { key: key, value: value });
  }
  function GM_deleteValue(key) {
    delete store[key];
    return post("deleteValue", { key: key });
  }

  function GM_xmlhttpRequest(details) {
    var d = details || {};
    var control = { abort: function () {} };
    post("xmlhttpRequest", {
      method: d.method || "GET",
      url: d.url,
      headers: d.headers || {},
      data: d.data != null ? String(d.data) : null,
      responseType: d.responseType || "",
      timeout: d.timeout || 0
    }).then(function (res) {
      if (res && res.status >= 200 && res.status < 400) {
        if (typeof d.onload === "function") d.onload(res);
      } else {
        if (typeof d.onerror === "function") d.onerror(res || { error: "request failed" });
      }
    }).catch(function (err) {
      if (typeof d.onerror === "function") {
        d.onerror({ error: (err && err.message) || "request failed" });
      }
    });
    return control;
  }

  function GM_setClipboard(text, info) {
    return post("setClipboard", { text: String(text), type: (info && info.type) || "text" });
  }
  function GM_openInTab(url, options) {
    var opts = (typeof options === "boolean") ? { active: !options } : (options || {});
    post("openInTab", { url: url, active: opts.active !== false });
    return { close: function () {} };
  }

  function GM_notification(a, b, c, d) {
    var o = (a && typeof a === "object") ? a : { text: a, title: b, image: c, onclick: d };
    post("notification", { title: o.title || "", text: o.text || o.body || "" });
    if (typeof o.ondone === "function") { try { o.ondone(); } catch (e) {} }
  }

  function GM_addStyle(css) {
    var style = document.createElement("style");
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);
    return style;
  }

  function GM_registerMenuCommand(name, callback) {
    var id = menuCommands.length;
    menuCommands.push({ name: name, callback: callback });
    post("registerMenuCommand", { name: name, id: id });
    return id;
  }
  function GM_unregisterMenuCommand(id) {
    if (menuCommands[id]) menuCommands[id] = null;
  }

  window.__wbInvokeMenuCommand = function (id) {
    var cmd = menuCommands[id];
    if (cmd && typeof cmd.callback === "function") cmd.callback();
  };

  var GM_info = ctx.info || {};

  var w = window;
  w.unsafeWindow = w;
  w.GM_getValue = GM_getValue;
  w.GM_setValue = GM_setValue;
  w.GM_deleteValue = GM_deleteValue;
  w.GM_listValues = GM_listValues;
  w.GM_xmlhttpRequest = GM_xmlhttpRequest;
  w.GM_setClipboard = GM_setClipboard;
  w.GM_openInTab = GM_openInTab;
  w.GM_addStyle = GM_addStyle;
  w.GM_registerMenuCommand = GM_registerMenuCommand;
  w.GM_unregisterMenuCommand = GM_unregisterMenuCommand;
  w.GM_notification = GM_notification;
  w.GM_info = GM_info;

  w.GM = {
    getValue: function (k, d) { return Promise.resolve(GM_getValue(k, d)); },
    setValue: GM_setValue,
    deleteValue: GM_deleteValue,
    listValues: function () { return Promise.resolve(GM_listValues()); },
    xmlHttpRequest: GM_xmlhttpRequest,
    setClipboard: GM_setClipboard,
    openInTab: GM_openInTab,
    addStyle: GM_addStyle,
    registerMenuCommand: GM_registerMenuCommand,
    notification: GM_notification,
    info: GM_info
  };
})();
