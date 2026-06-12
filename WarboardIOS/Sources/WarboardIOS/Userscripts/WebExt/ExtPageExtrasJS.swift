import Foundation

/// Extra page-world polyfills injected into rendered extension pages (options /
/// popup) only — NOT into content scripts or the background host.
///
/// ReTorn's `options.html` references the **jscolor** color-picker lib, which we
/// stripped from the bundle (GPL-3.0). `options.js` calls `element.jscolor
/// .fromString(...)` at load time, so a missing/undefined `jscolor` would throw
/// and blank the entire options page. This defines a bulletproof stub: an
/// `HTMLElement.prototype.jscolor` getter that lazily returns a no-op picker, so
/// the access can never throw regardless of timing or `jscolor.install()` order.
/// The only casualty is the (cosmetic) header-color picker; every real setting
/// toggle works.
enum ExtPageExtrasJS {
    static let source = #"""
    (function () {
      if (window.jscolor) return;
      function stubFor(el) {
        return {
          fromString: function (s) { try { el.value = s; } catch (e) {} },
          toString: function () { return el.value || ''; },
          option: function () {}, importColor: function () {}, hide: function () {}, show: function () {}
        };
      }
      try {
        Object.defineProperty(HTMLElement.prototype, 'jscolor', {
          configurable: true,
          get: function () { if (!this.__jscolorStub) this.__jscolorStub = stubFor(this); return this.__jscolorStub; },
          set: function (v) { this.__jscolorStub = v; }
        });
      } catch (e) {}
      function jscolor(el) { return el ? el.jscolor : undefined; }
      jscolor.install = function () {};
      jscolor.trigger = function () {};
      jscolor.presets = { default: {} };
      window.jscolor = jscolor;
    })();
    """#
}
