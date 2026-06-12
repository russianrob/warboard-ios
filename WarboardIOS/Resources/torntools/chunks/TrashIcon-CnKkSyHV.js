import { $ as mount, A as prop, At as user_derived, B as set_style, Bt as setContext, Ct as first_child, D as twMerge, Dt as set, E as extendTailwindMerge, F as bind_files, Ft as getAllContexts, H as clsx$1, Ht as next$1, I as bind_value, It as getContext, K as component, L as STYLE, Lt as hasContext, M as spread_props, Ot as state$1, P as bind_this, Q as if_block, R as attribute_effect, Rt as pop, St as child, T as cn$1, Tt as proxy, U as clsx, Ut as reset, V as set_class, Wt as noop$1, Y as each, Z as key, _t as effect_root, at as from_svg, bt as user_pre_effect, ct as delegate, dt as on, et as set_text, ft as createAttachmentKey, gt as untrack, ht as tick, it as from_html, j as rest_props, jt as createSubscriber, k as onMount, lt as delegated, mt as get$2, nt as append, ot as props_id, p as TO_MILLIS, q as snippet, r as derivedMode, rt as comment, s as settings, st as text, tt as unmount, ut as event, vt as template_effect, w as SvelteMap, wt as sibling, yt as user_effect, z as set_attribute, zt as push } from "./dist-DghMY0ja.js";
//#region node_modules/regexparam/dist/index.mjs
function parse(str, loose) {
	if (str instanceof RegExp) return {
		keys: false,
		pattern: str
	};
	var c, o, tmp, ext, keys = [], pattern = "", arr = str.split("/");
	arr[0] || arr.shift();
	while (tmp = arr.shift()) {
		c = tmp[0];
		if (c === "*") {
			keys.push("wild");
			pattern += "/(.*)";
		} else if (c === ":") {
			o = tmp.indexOf("?", 1);
			ext = tmp.indexOf(".", 1);
			keys.push(tmp.substring(1, !!~o ? o : !!~ext ? ext : tmp.length));
			pattern += !!~o && !~ext ? "(?:/([^/]+?))?" : "/([^/]+?)";
			if (!!~ext) pattern += (!!~o ? "?" : "") + "\\" + tmp.substring(ext);
		} else pattern += "/" + tmp;
	}
	return {
		keys,
		pattern: new RegExp("^" + pattern + (loose ? "(?=$|/)" : "/?$"), "i")
	};
}
//#endregion
//#region node_modules/svelte-spa-router/dist/Router.svelte
var RouterStateImpl = class {
	#_loc = state$1(getLocation());
	get _loc() {
		return get$2(this.#_loc);
	}
	set _loc(value) {
		set(this.#_loc, value);
	}
	#_location = user_derived(() => this._loc.location);
	get _location() {
		return get$2(this.#_location);
	}
	set _location(value) {
		set(this.#_location, value);
	}
	#_querystring = user_derived(() => this._loc.querystring);
	get _querystring() {
		return get$2(this.#_querystring);
	}
	set _querystring(value) {
		set(this.#_querystring, value);
	}
	#_params = state$1(void 0);
	get _params() {
		return get$2(this.#_params);
	}
	set _params(value) {
		set(this.#_params, value);
	}
	get loc() {
		return this._loc;
	}
	/** The current location (excluding querystring) */
	get location() {
		return this._location;
	}
	/** The current querystring */
	get querystring() {
		return this._querystring;
	}
	get params() {
		return this._params;
	}
	constructor() {
		window.addEventListener("hashchange", () => {
			this._loc = getLocation();
		});
	}
};
/** Router state object, containing the current location, querystring and params. */
var router = new RouterStateImpl();
/** Returns the current location from the hash. */
function getLocation() {
	const hashPosition = window.location.href.indexOf("#/");
	let location = hashPosition > -1 ? window.location.href.substr(hashPosition + 1) : "/";
	const qsPosition = location.indexOf("?");
	let querystring = "";
	if (qsPosition > -1) {
		querystring = location.substr(qsPosition + 1);
		location = location.substr(0, qsPosition);
	}
	return {
		location,
		querystring
	};
}
/**
* Replaces the current page but without modifying the history stack.
*
* @param location - Path to navigate to (must start with `/` or `#/`)
* @returns Promise that resolves after the page navigation has completed
*/
async function replace(location) {
	if (!location || location.length < 1 || location.charAt(0) != "/" && location.indexOf("#/") !== 0) throw Error("Invalid parameter location");
	await tick();
	const dest = (location.charAt(0) == "#" ? "" : "#") + location;
	try {
		const newState = { ...history.state };
		delete newState["__svelte_spa_router_scrollX"];
		delete newState["__svelte_spa_router_scrollY"];
		window.history.replaceState(newState, "", dest);
	} catch {
		console.warn("Caught exception while replacing the current page. If you're running this in the Svelte REPL, please note that the `replace` method might not work in this environment.");
	}
	window.dispatchEvent(new Event("hashchange"));
}
/**
* Svelte Action that enables a link element (`<a>`) to use our history management.
*
* For example:
*
* ```html
* <a href="/books" use:link>View books</a>
* ```
*/
function link(node, opts) {
	let currentOpts = linkOpts(opts);
	if (!node || !node.tagName || node.tagName.toLowerCase() != "a") throw Error("Action \"link\" can only be used with <a> tags");
	updateLinkHref(node, currentOpts);
	const clickHandler = (event) => {
		event.preventDefault();
		if (!currentOpts.disabled) {
			const target = event.currentTarget;
			const href = target ? target.getAttribute("href") : null;
			if (href) scrollstateHistoryHandler(href);
		}
	};
	node.addEventListener("click", clickHandler);
	return {
		update(updated) {
			currentOpts = linkOpts(updated);
			updateLinkHref(node, currentOpts);
		},
		destroy() {
			node.removeEventListener("click", clickHandler);
		}
	};
}
/** Tries to restore the scroll state from the given history state. */
function restoreScroll(state) {
	if (state) window.scrollTo(state.__svelte_spa_router_scrollX || 0, state.__svelte_spa_router_scrollY || 0);
	else window.scrollTo(0, 0);
}
function updateLinkHref(node, opts) {
	let href = opts.href || node.getAttribute("href");
	if (href && href.charAt(0) == "/") href = "#" + href;
	else if (!href || href.length < 2 || href.slice(0, 2) != "#/") throw Error("Invalid value for \"href\" attribute: " + href);
	node.setAttribute("href", href);
}
function linkOpts(val) {
	if (typeof val == "string") return { href: val };
	return val || {};
}
/**
* The handler attached to an anchor tag responsible for updating the
* current history state with the current scroll state.
*/
function scrollstateHistoryHandler(href) {
	history.replaceState({
		...history.state,
		__svelte_spa_router_scrollX: window.scrollX,
		__svelte_spa_router_scrollY: window.scrollY
	}, "");
	window.location.hash = href;
}
function Router($$anchor, $$props) {
	push($$props, true);
	const routes = prop($$props, "routes", 19, () => ({})), prefix = prop($$props, "prefix", 3, ""), restoreScrollState = prop($$props, "restoreScrollState", 3, false), onConditionsFailed = prop($$props, "onConditionsFailed", 3, () => {}), onRouteLoaded = prop($$props, "onRouteLoaded", 3, () => {}), onRouteLoading = prop($$props, "onRouteLoading", 3, () => {}), onRouteEvent = prop($$props, "onRouteEvent", 3, () => {});
	/** Container for a route: path, component */
	class RouteItem {
		path;
		component;
		conditions;
		userData;
		props;
		_pattern;
		_keys;
		constructor(path, component) {
			const isWrapped = (c) => typeof c == "object" && c !== null && c._sveltesparouter === true;
			if (!component || typeof component != "function" && !isWrapped(component)) throw Error("Invalid component object");
			if (!path || typeof path == "string" && (path.length < 1 || path.charAt(0) != "/" && path.charAt(0) != "*") || typeof path == "object" && !(path instanceof RegExp)) throw Error("Invalid value for \"path\" argument - strings must start with / or *");
			const parsed = typeof path == "string" ? parse(path) : parse(path);
			this.path = path;
			if (isWrapped(component)) {
				const wrapped = component;
				this.component = wrapped.component;
				this.conditions = wrapped.conditions || [];
				this.userData = wrapped.userData;
				this.props = wrapped.props || {};
			} else {
				const sync = component;
				this.component = () => Promise.resolve(sync);
				this.conditions = [];
				this.props = {};
			}
			this._pattern = parsed.pattern;
			this._keys = parsed.keys;
		}
		/**
		* Checks if `path` matches the current route.
		* Returns the list of parameters from the URL, or `null` if no match.
		*/
		match(path) {
			if (prefix()) {
				if (typeof prefix() == "string") if (path.startsWith(prefix())) path = path.substr(prefix().length) || "/";
				else return null;
				else if (prefix() instanceof RegExp) {
					const m = path.match(prefix());
					if (m && m[0]) path = path.substr(m[0].length) || "/";
					else return null;
				}
			}
			const matches = this._pattern.exec(path);
			if (matches === null) return null;
			if (this._keys === false) return matches;
			const out = {};
			let i = 0;
			while (i < this._keys.length) {
				try {
					out[this._keys[i]] = decodeURIComponent(matches[i + 1] || "") || null;
				} catch {
					out[this._keys[i]] = null;
				}
				i++;
			}
			return out;
		}
		/** Executes all conditions in order; returns false at the first failure. */
		async checkConditions(detail) {
			for (let i = 0; i < this.conditions.length; i++) if (!await this.conditions[i](detail)) return false;
			return true;
		}
	}
	const routesList = [];
	if (routes() instanceof Map) routes().forEach((route, path) => {
		routesList.push(new RouteItem(path, route));
	});
	else Object.keys(routes()).forEach((path) => {
		const map = routes();
		routesList.push(new RouteItem(path, map[path]));
	});
	let component$1 = state$1(null);
	let componentParams = state$1(null);
	let routeProps = state$1({});
	let previousScrollState = null;
	let componentObj = null;
	user_effect(() => {
		history.scrollRestoration = restoreScrollState() ? "manual" : "auto";
	});
	user_effect(() => {
		if (!restoreScrollState()) return;
		const popStateChanged = (event) => {
			if (event.state && (event.state.__svelte_spa_router_scrollY || event.state.__svelte_spa_router_scrollX)) previousScrollState = event.state;
			else previousScrollState = null;
		};
		window.addEventListener("popstate", popStateChanged);
		return () => window.removeEventListener("popstate", popStateChanged);
	});
	async function dispatchNextTick(event, detail) {
		await tick();
		event(detail);
	}
	user_effect(() => {
		const newLoc = router.loc;
		let cancelled = false;
		untrack(async () => {
			let i = 0;
			while (i < routesList.length) {
				const match = routesList[i].match(newLoc.location);
				if (!match) {
					i++;
					continue;
				}
				const matchParams = matchToParams(match);
				const detail = {
					route: routesList[i].path,
					location: newLoc.location,
					querystring: newLoc.querystring || "",
					userData: routesList[i].userData,
					params: matchParams
				};
				if (!await routesList[i].checkConditions(detail)) {
					if (cancelled) return;
					set(component$1, null);
					componentObj = null;
					dispatchNextTick(onConditionsFailed(), detail);
					return;
				}
				if (cancelled) return;
				dispatchNextTick(onRouteLoading(), { ...detail });
				const obj = routesList[i].component;
				if (componentObj != obj) {
					if (obj.loading) {
						set(component$1, obj.loading);
						componentObj = obj;
						set(componentParams, obj.loadingParams || null);
						set(routeProps, {});
						const comp = obj.loading;
						dispatchNextTick(onRouteLoaded(), {
							...detail,
							component: comp,
							name: comp.name,
							params: obj.loadingParams || null
						});
					} else {
						set(component$1, null);
						componentObj = null;
					}
					const loaded = await obj();
					if (cancelled) return;
					set(component$1, loaded && typeof loaded == "object" && "default" in loaded ? loaded.default : loaded);
					componentObj = obj;
				}
				set(componentParams, matchParams);
				set(routeProps, routesList[i].props);
				const comp = get$2(component$1);
				if (comp) dispatchNextTick(onRouteLoaded(), {
					...detail,
					component: comp,
					name: comp.name,
					params: matchParams
				});
				router._params = matchParams;
				if (restoreScrollState()) {
					restoreScroll(previousScrollState);
					previousScrollState = null;
				}
				return;
			}
			set(component$1, null);
			componentObj = null;
			router._params = void 0;
			if (restoreScrollState()) {
				restoreScroll(previousScrollState);
				previousScrollState = null;
			}
		});
		return () => {
			cancelled = true;
		};
	});
	function matchToParams(match) {
		return match && typeof match == "object" && Object.keys(match).length ? match : null;
	}
	var fragment = comment();
	var node_1 = first_child(fragment);
	var consequent_1 = ($$anchor) => {
		const Component = user_derived(() => get$2(component$1));
		var fragment_1 = comment();
		var node_2 = first_child(fragment_1);
		var consequent = ($$anchor) => {
			var fragment_2 = comment();
			component(first_child(fragment_2), () => get$2(Component), ($$anchor, Component_1) => {
				Component_1($$anchor, spread_props({
					get params() {
						return get$2(componentParams);
					},
					get onRouteEvent() {
						return onRouteEvent();
					}
				}, () => get$2(routeProps)));
			});
			append($$anchor, fragment_2);
		};
		var alternate = ($$anchor) => {
			var fragment_3 = comment();
			component(first_child(fragment_3), () => get$2(Component), ($$anchor, Component_2) => {
				Component_2($$anchor, spread_props({ get onRouteEvent() {
					return onRouteEvent();
				} }, () => get$2(routeProps)));
			});
			append($$anchor, fragment_3);
		};
		if_block(node_2, ($$render) => {
			if (get$2(componentParams)) $$render(consequent);
			else $$render(alternate, -1);
		});
		append($$anchor, fragment_1);
	};
	if_block(node_1, ($$render) => {
		if (get$2(component$1)) $$render(consequent_1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/is.js
function isFunction$1(value) {
	return typeof value === "function";
}
function isObject(value) {
	return value !== null && typeof value === "object";
}
var CLASS_VALUE_PRIMITIVE_TYPES = [
	"string",
	"number",
	"bigint",
	"boolean"
];
function isClassValue(value) {
	if (value === null || value === void 0) return true;
	if (CLASS_VALUE_PRIMITIVE_TYPES.includes(typeof value)) return true;
	if (Array.isArray(value)) return value.every((item) => isClassValue(item));
	if (typeof value === "object") {
		if (Object.getPrototypeOf(value) !== Object.prototype) return false;
		return true;
	}
	return false;
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/box/box-extras.svelte.js
var BoxSymbol = Symbol("box");
var isWritableSymbol = Symbol("is-writable");
function boxWith(getter, setter) {
	const derived = user_derived(getter);
	if (setter) return {
		[BoxSymbol]: true,
		[isWritableSymbol]: true,
		get current() {
			return get$2(derived);
		},
		set current(v) {
			setter(v);
		}
	};
	return {
		[BoxSymbol]: true,
		get current() {
			return getter();
		}
	};
}
/**
* @returns Whether the value is a Box
*
* @see {@link https://runed.dev/docs/functions/box}
*/
function isBox(value) {
	return isObject(value) && BoxSymbol in value;
}
/**
* @returns Whether the value is a WritableBox
*
* @see {@link https://runed.dev/docs/functions/box}
*/
function isWritableBox(value) {
	return isBox(value) && isWritableSymbol in value;
}
function boxFrom(value) {
	if (isBox(value)) return value;
	if (isFunction$1(value)) return boxWith(value);
	return simpleBox(value);
}
/**
* Function that gets an object of boxes, and returns an object of reactive values
*
* @example
* const count = box(0)
* const flat = box.flatten({ count, double: box.with(() => count.current) })
* // type of flat is { count: number, readonly double: number }
*
* @see {@link https://runed.dev/docs/functions/box}
*/
function boxFlatten(boxes) {
	return Object.entries(boxes).reduce((acc, [key, b]) => {
		if (!isBox(b)) return Object.assign(acc, { [key]: b });
		if (isWritableBox(b)) Object.defineProperty(acc, key, {
			get() {
				return b.current;
			},
			set(v) {
				b.current = v;
			}
		});
		else Object.defineProperty(acc, key, { get() {
			return b.current;
		} });
		return acc;
	}, {});
}
/**
* Function that converts a box to a readonly box.
*
* @example
* const count = box(0) // WritableBox<number>
* const countReadonly = box.readonly(count) // ReadableBox<number>
*
* @see {@link https://runed.dev/docs/functions/box}
*/
function toReadonlyBox(b) {
	if (!isWritableBox(b)) return b;
	return {
		[BoxSymbol]: true,
		get current() {
			return b.current;
		}
	};
}
function simpleBox(initialValue) {
	let current = state$1(proxy(initialValue));
	return {
		[BoxSymbol]: true,
		[isWritableSymbol]: true,
		get current() {
			return get$2(current);
		},
		set current(v) {
			set(current, v, true);
		}
	};
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/box/box.svelte.js
function box(initialValue) {
	let current = state$1(proxy(initialValue));
	return {
		[BoxSymbol]: true,
		[isWritableSymbol]: true,
		get current() {
			return get$2(current);
		},
		set current(v) {
			set(current, v, true);
		}
	};
}
box.from = boxFrom;
box.with = boxWith;
box.flatten = boxFlatten;
box.readonly = toReadonlyBox;
box.isBox = isBox;
box.isWritableBox = isWritableBox;
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/compose-handlers.js
/**
* Composes event handlers into a single function that can be called with an event.
* If the previous handler cancels the event using `event.preventDefault()`, the handlers
* that follow will not be called.
*/
function composeHandlers(...handlers) {
	return function(e) {
		for (const handler of handlers) {
			if (!handler) continue;
			if (e.defaultPrevented) return;
			if (typeof handler === "function") handler.call(this, e);
			else handler.current?.call(this, e);
		}
	};
}
//#endregion
//#region node_modules/inline-style-parser/esm/index.mjs
var COMMENT_REGEX = /\/\*[^*]*\*+([^/*][^*]*\*+)*\//g;
var NEWLINE_REGEX = /\n/g;
var WHITESPACE_REGEX = /^\s*/;
var PROPERTY_REGEX = /^(\*?[-#/*\\\w]+(\[[0-9a-z_-]+\])?)\s*/;
var COLON_REGEX = /^:\s*/;
var VALUE_REGEX = /^((?:'(?:\\'|.)*?'|"(?:\\"|.)*?"|\([^)]*?\)|[^};])+)/;
var SEMICOLON_REGEX = /^[;\s]*/;
var TRIM_REGEX = /^\s+|\s+$/g;
var NEWLINE = "\n";
var FORWARD_SLASH = "/";
var ASTERISK = "*";
var EMPTY_STRING = "";
var TYPE_COMMENT = "comment";
var TYPE_DECLARATION = "declaration";
/**
* @param {String} style
* @param {Object} [options]
* @return {Object[]}
* @throws {TypeError}
* @throws {Error}
*/
function index(style, options) {
	if (typeof style !== "string") throw new TypeError("First argument must be a string");
	if (!style) return [];
	options = options || {};
	/**
	* Positional.
	*/
	var lineno = 1;
	var column = 1;
	/**
	* Update lineno and column based on `str`.
	*
	* @param {String} str
	*/
	function updatePosition(str) {
		var lines = str.match(NEWLINE_REGEX);
		if (lines) lineno += lines.length;
		var i = str.lastIndexOf(NEWLINE);
		column = ~i ? str.length - i : column + str.length;
	}
	/**
	* Mark position and patch `node.position`.
	*
	* @return {Function}
	*/
	function position() {
		var start = {
			line: lineno,
			column
		};
		return function(node) {
			node.position = new Position(start);
			whitespace();
			return node;
		};
	}
	/**
	* Store position information for a node.
	*
	* @constructor
	* @property {Object} start
	* @property {Object} end
	* @property {undefined|String} source
	*/
	function Position(start) {
		this.start = start;
		this.end = {
			line: lineno,
			column
		};
		this.source = options.source;
	}
	/**
	* Non-enumerable source string.
	*/
	Position.prototype.content = style;
	/**
	* Error `msg`.
	*
	* @param {String} msg
	* @throws {Error}
	*/
	function error(msg) {
		var err = /* @__PURE__ */ new Error(options.source + ":" + lineno + ":" + column + ": " + msg);
		err.reason = msg;
		err.filename = options.source;
		err.line = lineno;
		err.column = column;
		err.source = style;
		if (options.silent);
		else throw err;
	}
	/**
	* Match `re` and return captures.
	*
	* @param {RegExp} re
	* @return {undefined|Array}
	*/
	function match(re) {
		var m = re.exec(style);
		if (!m) return;
		var str = m[0];
		updatePosition(str);
		style = style.slice(str.length);
		return m;
	}
	/**
	* Parse whitespace.
	*/
	function whitespace() {
		match(WHITESPACE_REGEX);
	}
	/**
	* Parse comments.
	*
	* @param {Object[]} [rules]
	* @return {Object[]}
	*/
	function comments(rules) {
		var c;
		rules = rules || [];
		while (c = comment()) if (c !== false) rules.push(c);
		return rules;
	}
	/**
	* Parse comment.
	*
	* @return {Object}
	* @throws {Error}
	*/
	function comment() {
		var pos = position();
		if (FORWARD_SLASH != style.charAt(0) || ASTERISK != style.charAt(1)) return;
		var i = 2;
		while (EMPTY_STRING != style.charAt(i) && (ASTERISK != style.charAt(i) || FORWARD_SLASH != style.charAt(i + 1))) ++i;
		i += 2;
		if (EMPTY_STRING === style.charAt(i - 1)) return error("End of comment missing");
		var str = style.slice(2, i - 2);
		column += 2;
		updatePosition(str);
		style = style.slice(i);
		column += 2;
		return pos({
			type: TYPE_COMMENT,
			comment: str
		});
	}
	/**
	* Parse declaration.
	*
	* @return {Object}
	* @throws {Error}
	*/
	function declaration() {
		var pos = position();
		var prop = match(PROPERTY_REGEX);
		if (!prop) return;
		comment();
		if (!match(COLON_REGEX)) return error("property missing ':'");
		var val = match(VALUE_REGEX);
		var ret = pos({
			type: TYPE_DECLARATION,
			property: trim(prop[0].replace(COMMENT_REGEX, EMPTY_STRING)),
			value: val ? trim(val[0].replace(COMMENT_REGEX, EMPTY_STRING)) : EMPTY_STRING
		});
		match(SEMICOLON_REGEX);
		return ret;
	}
	/**
	* Parse declarations.
	*
	* @return {Object[]}
	*/
	function declarations() {
		var decls = [];
		comments(decls);
		var decl;
		while (decl = declaration()) if (decl !== false) {
			decls.push(decl);
			comments(decls);
		}
		return decls;
	}
	whitespace();
	return declarations();
}
/**
* Trim `str`.
*
* @param {String} str
* @return {String}
*/
function trim(str) {
	return str ? str.replace(TRIM_REGEX, EMPTY_STRING) : EMPTY_STRING;
}
//#endregion
//#region node_modules/style-to-object/esm/index.mjs
/**
* Parses inline style to object.
*
* @param style - Inline style.
* @param iterator - Iterator.
* @returns - Style object or null.
*
* @example Parsing inline style to object:
*
* ```js
* import parse from 'style-to-object';
* parse('line-height: 42;'); // { 'line-height': '42' }
* ```
*/
function StyleToObject(style, iterator) {
	let styleObject = null;
	if (!style || typeof style !== "string") return styleObject;
	const declarations = index(style);
	const hasIterator = typeof iterator === "function";
	declarations.forEach((declaration) => {
		if (declaration.type !== "declaration") return;
		const { property, value } = declaration;
		if (hasIterator) iterator(property, value, declaration);
		else if (value) {
			styleObject = styleObject || {};
			styleObject[property] = value;
		}
	});
	return styleObject;
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/strings.js
var NUMBER_CHAR_RE = /\d/;
var STR_SPLITTERS = [
	"-",
	"_",
	"/",
	"."
];
function isUppercase(char = "") {
	if (NUMBER_CHAR_RE.test(char)) return void 0;
	return char !== char.toLowerCase();
}
function splitByCase(str) {
	const parts = [];
	let buff = "";
	let previousUpper;
	let previousSplitter;
	for (const char of str) {
		const isSplitter = STR_SPLITTERS.includes(char);
		if (isSplitter === true) {
			parts.push(buff);
			buff = "";
			previousUpper = void 0;
			continue;
		}
		const isUpper = isUppercase(char);
		if (previousSplitter === false) {
			if (previousUpper === false && isUpper === true) {
				parts.push(buff);
				buff = char;
				previousUpper = isUpper;
				continue;
			}
			if (previousUpper === true && isUpper === false && buff.length > 1) {
				const lastChar = buff.at(-1);
				parts.push(buff.slice(0, Math.max(0, buff.length - 1)));
				buff = lastChar + char;
				previousUpper = isUpper;
				continue;
			}
		}
		buff += char;
		previousUpper = isUpper;
		previousSplitter = isSplitter;
	}
	parts.push(buff);
	return parts;
}
function pascalCase(str) {
	if (!str) return "";
	return splitByCase(str).map((p) => upperFirst(p)).join("");
}
function camelCase(str) {
	return lowerFirst(pascalCase(str || ""));
}
function upperFirst(str) {
	return str ? str[0].toUpperCase() + str.slice(1) : "";
}
function lowerFirst(str) {
	return str ? str[0].toLowerCase() + str.slice(1) : "";
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/css-to-style-obj.js
function cssToStyleObj(css) {
	if (!css) return {};
	const styleObj = {};
	function iterator(name, value) {
		if (name.startsWith("-moz-") || name.startsWith("-webkit-") || name.startsWith("-ms-") || name.startsWith("-o-")) {
			styleObj[pascalCase(name)] = value;
			return;
		}
		if (name.startsWith("--")) {
			styleObj[name] = value;
			return;
		}
		styleObj[camelCase(name)] = value;
	}
	StyleToObject(css, iterator);
	return styleObj;
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/execute-callbacks.js
/**
* Executes an array of callback functions with the same arguments.
* @template T The types of the arguments that the callback functions take.
* @param callbacks array of callback functions to execute.
* @returns A new function that executes all of the original callback functions with the same arguments.
*/
function executeCallbacks(...callbacks) {
	return (...args) => {
		for (const callback of callbacks) if (typeof callback === "function") callback(...args);
	};
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/style-to-css.js
function createParser(matcher, replacer) {
	const regex = RegExp(matcher, "g");
	return (str) => {
		if (typeof str !== "string") throw new TypeError(`expected an argument of type string, but got ${typeof str}`);
		if (!str.match(regex)) return str;
		return str.replace(regex, replacer);
	};
}
var camelToKebab = createParser(/[A-Z]/, (match) => `-${match.toLowerCase()}`);
function styleToCSS(styleObj) {
	if (!styleObj || typeof styleObj !== "object" || Array.isArray(styleObj)) throw new TypeError(`expected an argument of type object, but got ${typeof styleObj}`);
	return Object.keys(styleObj).map((property) => `${camelToKebab(property)}: ${styleObj[property]};`).join("\n");
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/style.js
function styleToString(style = {}) {
	return styleToCSS(style).replace("\n", " ");
}
var EVENT_LIST_SET = new Set([
	"onabort",
	"onanimationcancel",
	"onanimationend",
	"onanimationiteration",
	"onanimationstart",
	"onauxclick",
	"onbeforeinput",
	"onbeforetoggle",
	"onblur",
	"oncancel",
	"oncanplay",
	"oncanplaythrough",
	"onchange",
	"onclick",
	"onclose",
	"oncompositionend",
	"oncompositionstart",
	"oncompositionupdate",
	"oncontextlost",
	"oncontextmenu",
	"oncontextrestored",
	"oncopy",
	"oncuechange",
	"oncut",
	"ondblclick",
	"ondrag",
	"ondragend",
	"ondragenter",
	"ondragleave",
	"ondragover",
	"ondragstart",
	"ondrop",
	"ondurationchange",
	"onemptied",
	"onended",
	"onerror",
	"onfocus",
	"onfocusin",
	"onfocusout",
	"onformdata",
	"ongotpointercapture",
	"oninput",
	"oninvalid",
	"onkeydown",
	"onkeypress",
	"onkeyup",
	"onload",
	"onloadeddata",
	"onloadedmetadata",
	"onloadstart",
	"onlostpointercapture",
	"onmousedown",
	"onmouseenter",
	"onmouseleave",
	"onmousemove",
	"onmouseout",
	"onmouseover",
	"onmouseup",
	"onpaste",
	"onpause",
	"onplay",
	"onplaying",
	"onpointercancel",
	"onpointerdown",
	"onpointerenter",
	"onpointerleave",
	"onpointermove",
	"onpointerout",
	"onpointerover",
	"onpointerup",
	"onprogress",
	"onratechange",
	"onreset",
	"onresize",
	"onscroll",
	"onscrollend",
	"onsecuritypolicyviolation",
	"onseeked",
	"onseeking",
	"onselect",
	"onselectionchange",
	"onselectstart",
	"onslotchange",
	"onstalled",
	"onsubmit",
	"onsuspend",
	"ontimeupdate",
	"ontoggle",
	"ontouchcancel",
	"ontouchend",
	"ontouchmove",
	"ontouchstart",
	"ontransitioncancel",
	"ontransitionend",
	"ontransitionrun",
	"ontransitionstart",
	"onvolumechange",
	"onwaiting",
	"onwebkitanimationend",
	"onwebkitanimationiteration",
	"onwebkitanimationstart",
	"onwebkittransitionend",
	"onwheel"
]);
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/merge-props.js
/**
* Modified from https://github.com/adobe/react-spectrum/blob/main/packages/%40react-aria/utils/src/mergeProps.ts (see NOTICE.txt for source)
*/
function isEventHandler(key) {
	return EVENT_LIST_SET.has(key);
}
/**
* Given a list of prop objects, merges them into a single object.
* - Automatically composes event handlers (e.g. `onclick`, `oninput`, etc.)
* - Chains regular functions with the same name so they are called in order
* - Merges class strings with `clsx`
* - Merges style objects and converts them to strings
* - Handles a bug with Svelte where setting the `hidden` attribute to `false` doesn't remove it
* - Overrides other values with the last one
*/
function mergeProps(...args) {
	const result = { ...args[0] };
	for (let i = 1; i < args.length; i++) {
		const props = args[i];
		if (!props) continue;
		for (const key of Object.keys(props)) {
			const a = result[key];
			const b = props[key];
			const aIsFunction = typeof a === "function";
			const bIsFunction = typeof b === "function";
			if (aIsFunction && typeof bIsFunction && isEventHandler(key)) result[key] = composeHandlers(a, b);
			else if (aIsFunction && bIsFunction) result[key] = executeCallbacks(a, b);
			else if (key === "class") {
				const aIsClassValue = isClassValue(a);
				const bIsClassValue = isClassValue(b);
				if (aIsClassValue && bIsClassValue) result[key] = clsx(a, b);
				else if (aIsClassValue) result[key] = clsx(a);
				else if (bIsClassValue) result[key] = clsx(b);
			} else if (key === "style") {
				const aIsObject = typeof a === "object";
				const bIsObject = typeof b === "object";
				const aIsString = typeof a === "string";
				const bIsString = typeof b === "string";
				if (aIsObject && bIsObject) result[key] = {
					...a,
					...b
				};
				else if (aIsObject && bIsString) {
					const parsedStyle = cssToStyleObj(b);
					result[key] = {
						...a,
						...parsedStyle
					};
				} else if (aIsString && bIsObject) result[key] = {
					...cssToStyleObj(a),
					...b
				};
				else if (aIsString && bIsString) {
					const parsedStyleA = cssToStyleObj(a);
					const parsedStyleB = cssToStyleObj(b);
					result[key] = {
						...parsedStyleA,
						...parsedStyleB
					};
				} else if (aIsObject) result[key] = a;
				else if (bIsObject) result[key] = b;
				else if (aIsString) result[key] = a;
				else if (bIsString) result[key] = b;
			} else result[key] = b !== void 0 ? b : a;
		}
		for (const key of Object.getOwnPropertySymbols(props)) {
			const a = result[key];
			const b = props[key];
			result[key] = b !== void 0 ? b : a;
		}
	}
	if (typeof result.style === "object") result.style = styleToString(result.style).replaceAll("\n", " ");
	if (result.hidden === false) {
		result.hidden = void 0;
		delete result.hidden;
	}
	if (result.disabled === false) {
		result.disabled = void 0;
		delete result.disabled;
	}
	return result;
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/sr-only-styles.js
var srOnlyStyles = {
	position: "absolute",
	width: "1px",
	height: "1px",
	padding: "0",
	margin: "-1px",
	overflow: "hidden",
	clip: "rect(0, 0, 0, 0)",
	whiteSpace: "nowrap",
	borderWidth: "0",
	transform: "translateX(-100%)"
};
styleToString(srOnlyStyles);
//#endregion
//#region node_modules/runed/dist/internal/configurable-globals.js
var defaultWindow$1 = typeof window !== "undefined" ? window : void 0;
typeof window !== "undefined" && window.document;
typeof window !== "undefined" && window.navigator;
typeof window !== "undefined" && window.location;
//#endregion
//#region node_modules/runed/dist/internal/utils/dom.js
/**
* Handles getting the active element in a document or shadow root.
* If the active element is within a shadow root, it will traverse the shadow root
* to find the active element.
* If not, it will return the active element in the document.
*
* @param document A document or shadow root to get the active element from.
* @returns The active element in the document or shadow root.
*/
function getActiveElement$2(document) {
	let activeElement = document.activeElement;
	while (activeElement?.shadowRoot) {
		const node = activeElement.shadowRoot.activeElement;
		if (node === activeElement) break;
		else activeElement = node;
	}
	return activeElement;
}
//#endregion
//#region node_modules/runed/dist/utilities/active-element/active-element.svelte.js
var ActiveElement$1 = class {
	#document;
	#subscribe;
	constructor(options = {}) {
		const { window = defaultWindow$1, document = window?.document } = options;
		if (window === void 0) return;
		this.#document = document;
		this.#subscribe = createSubscriber((update) => {
			const cleanupFocusIn = on(window, "focusin", update);
			const cleanupFocusOut = on(window, "focusout", update);
			return () => {
				cleanupFocusIn();
				cleanupFocusOut();
			};
		});
	}
	get current() {
		this.#subscribe?.();
		if (!this.#document) return null;
		return getActiveElement$2(this.#document);
	}
};
new ActiveElement$1();
//#endregion
//#region node_modules/runed/dist/internal/utils/is.js
function isFunction(value) {
	return typeof value === "function";
}
//#endregion
//#region node_modules/runed/dist/utilities/context/context.js
var Context$1 = class {
	#name;
	#key;
	/**
	* @param name The name of the context.
	* This is used for generating the context key and error messages.
	*/
	constructor(name) {
		this.#name = name;
		this.#key = Symbol(name);
	}
	/**
	* The key used to get and set the context.
	*
	* It is not recommended to use this value directly.
	* Instead, use the methods provided by this class.
	*/
	get key() {
		return this.#key;
	}
	/**
	* Checks whether this has been set in the context of a parent component.
	*
	* Must be called during component initialisation.
	*/
	exists() {
		return hasContext(this.#key);
	}
	/**
	* Retrieves the context that belongs to the closest parent component.
	*
	* Must be called during component initialisation.
	*
	* @throws An error if the context does not exist.
	*/
	get() {
		const context = getContext(this.#key);
		if (context === void 0) throw new Error(`Context "${this.#name}" not found`);
		return context;
	}
	/**
	* Retrieves the context that belongs to the closest parent component,
	* or the given fallback value if the context does not exist.
	*
	* Must be called during component initialisation.
	*/
	getOr(fallback) {
		const context = getContext(this.#key);
		if (context === void 0) return fallback;
		return context;
	}
	/**
	* Associates the given value with the current component and returns it.
	*
	* Must be called during component initialisation.
	*/
	set(context) {
		return setContext(this.#key, context);
	}
};
//#endregion
//#region node_modules/runed/dist/utilities/watch/watch.svelte.js
function runEffect$1(flush, effect) {
	switch (flush) {
		case "post":
			user_effect(effect);
			break;
		case "pre":
			user_pre_effect(effect);
			break;
	}
}
function runWatcher$1(sources, flush, effect, options = {}) {
	const { lazy = false } = options;
	let active = !lazy;
	let previousValues = Array.isArray(sources) ? [] : void 0;
	runEffect$1(flush, () => {
		const values = Array.isArray(sources) ? sources.map((source) => source()) : sources();
		if (!active) {
			active = true;
			previousValues = values;
			return;
		}
		const cleanup = untrack(() => effect(values, previousValues));
		previousValues = values;
		return cleanup;
	});
}
function runWatcherOnce$1(sources, flush, effect) {
	const cleanupRoot = effect_root(() => {
		let stop = false;
		runWatcher$1(sources, flush, (values, previousValues) => {
			if (stop) {
				cleanupRoot();
				return;
			}
			const cleanup = effect(values, previousValues);
			stop = true;
			return cleanup;
		}, { lazy: true });
	});
	user_effect(() => {
		return cleanupRoot;
	});
}
function watch$1(sources, effect, options) {
	runWatcher$1(sources, "post", effect, options);
}
function watchPre$1(sources, effect, options) {
	runWatcher$1(sources, "pre", effect, options);
}
watch$1.pre = watchPre$1;
function watchOnce$1(source, effect) {
	runWatcherOnce$1(source, "post", effect);
}
function watchOncePre$1(source, effect) {
	runWatcherOnce$1(source, "pre", effect);
}
watchOnce$1.pre = watchOncePre$1;
//#endregion
//#region node_modules/runed/dist/internal/utils/get.js
function get$1(value) {
	if (isFunction(value)) return value();
	return value;
}
//#endregion
//#region node_modules/runed/dist/utilities/element-size/element-size.svelte.js
var ElementSize = class {
	#size = {
		width: 0,
		height: 0
	};
	#observed = false;
	#options;
	#node;
	#window;
	#width = user_derived(() => {
		get$2(this.#subscribe)?.();
		return this.getSize().width;
	});
	#height = user_derived(() => {
		get$2(this.#subscribe)?.();
		return this.getSize().height;
	});
	#subscribe = user_derived(() => {
		const node$ = get$1(this.#node);
		if (!node$) return;
		return createSubscriber((update) => {
			if (!this.#window) return;
			const observer = new this.#window.ResizeObserver((entries) => {
				this.#observed = true;
				for (const entry of entries) {
					const boxSize = this.#options.box === "content-box" ? entry.contentBoxSize : entry.borderBoxSize;
					const boxSizeArr = Array.isArray(boxSize) ? boxSize : [boxSize];
					this.#size.width = boxSizeArr.reduce((acc, size) => Math.max(acc, size.inlineSize), 0);
					this.#size.height = boxSizeArr.reduce((acc, size) => Math.max(acc, size.blockSize), 0);
				}
				update();
			});
			observer.observe(node$);
			return () => {
				this.#observed = false;
				observer.disconnect();
			};
		});
	});
	constructor(node, options = { box: "border-box" }) {
		this.#window = options.window ?? defaultWindow$1;
		this.#options = options;
		this.#node = node;
		this.#size = {
			width: 0,
			height: 0
		};
	}
	calculateSize() {
		const element = get$1(this.#node);
		if (!element || !this.#window) return;
		const offsetWidth = element.offsetWidth;
		const offsetHeight = element.offsetHeight;
		if (this.#options.box === "border-box") return {
			width: offsetWidth,
			height: offsetHeight
		};
		const style = this.#window.getComputedStyle(element);
		const paddingWidth = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
		const paddingHeight = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
		const borderWidth = parseFloat(style.borderLeftWidth) + parseFloat(style.borderRightWidth);
		const borderHeight = parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth);
		return {
			width: offsetWidth - paddingWidth - borderWidth,
			height: offsetHeight - paddingHeight - borderHeight
		};
	}
	getSize() {
		return this.#observed ? this.#size : this.calculateSize() ?? this.#size;
	}
	get current() {
		get$2(this.#subscribe)?.();
		return this.getSize();
	}
	get width() {
		return get$2(this.#width);
	}
	get height() {
		return get$2(this.#height);
	}
};
//#endregion
//#region node_modules/runed/dist/utilities/previous/previous.svelte.js
var Previous = class {
	#previousCallback = () => void 0;
	#previous = user_derived(() => this.#previousCallback());
	constructor(getter, initialValue) {
		let actualPrevious = void 0;
		if (initialValue !== void 0) actualPrevious = initialValue;
		this.#previousCallback = () => {
			try {
				return actualPrevious;
			} finally {
				actualPrevious = getter();
			}
		};
	}
	get current() {
		return get$2(this.#previous);
	}
};
//#endregion
//#region node_modules/runed/dist/utilities/resource/resource.svelte.js
function debounce$2(fn, delay) {
	let timeoutId;
	let lastResolve = null;
	return (...args) => {
		return new Promise((resolve) => {
			if (lastResolve) lastResolve(void 0);
			lastResolve = resolve;
			clearTimeout(timeoutId);
			timeoutId = setTimeout(async () => {
				const result = await fn(...args);
				if (lastResolve) {
					lastResolve(result);
					lastResolve = null;
				}
			}, delay);
		});
	};
}
function throttle$1(fn, delay) {
	let lastRun = 0;
	let lastPromise = null;
	return (...args) => {
		const now = Date.now();
		if (lastRun && now - lastRun < delay) return lastPromise ?? Promise.resolve(void 0);
		lastRun = now;
		lastPromise = fn(...args);
		return lastPromise;
	};
}
function runResource$1(source, fetcher, options = {}, effectFn) {
	const { lazy = false, once = false, initialValue, debounce: debounceTime, throttle: throttleTime } = options;
	let current = state$1(proxy(initialValue));
	let loading = state$1(false);
	let error = state$1(void 0);
	let cleanupFns = state$1(proxy([]));
	const runCleanup = () => {
		get$2(cleanupFns).forEach((fn) => fn());
		set(cleanupFns, [], true);
	};
	const onCleanup = (fn) => {
		set(cleanupFns, [...get$2(cleanupFns), fn], true);
	};
	const baseFetcher = async (value, previousValue, refetching = false) => {
		try {
			set(loading, true);
			set(error, void 0);
			runCleanup();
			const controller = new AbortController();
			onCleanup(() => controller.abort());
			const result = await fetcher(value, previousValue, {
				data: get$2(current),
				refetching,
				onCleanup,
				signal: controller.signal
			});
			set(current, result, true);
			return result;
		} catch (e) {
			if (!(e instanceof DOMException && e.name === "AbortError")) set(error, e, true);
			return;
		} finally {
			set(loading, false);
		}
	};
	const runFetcher = debounceTime ? debounce$2(baseFetcher, debounceTime) : throttleTime ? throttle$1(baseFetcher, throttleTime) : baseFetcher;
	const sources = Array.isArray(source) ? source : [source];
	let prevValues;
	effectFn((values, previousValues) => {
		if (once && prevValues) return;
		prevValues = values;
		runFetcher(Array.isArray(source) ? values : values[0], Array.isArray(source) ? previousValues : previousValues?.[0]);
	}, { lazy });
	return {
		get current() {
			return get$2(current);
		},
		get loading() {
			return get$2(loading);
		},
		get error() {
			return get$2(error);
		},
		mutate: (value) => {
			set(current, value, true);
		},
		refetch: (info) => {
			const values = sources.map((s) => s());
			return runFetcher(Array.isArray(source) ? values : values[0], Array.isArray(source) ? values : values[0], info ?? true);
		}
	};
}
function resource$1(source, fetcher, options) {
	return runResource$1(source, fetcher, options, (fn, options) => {
		const sources = Array.isArray(source) ? source : [source];
		const getters = () => sources.map((s) => s());
		watch$1(getters, (values, previousValues) => {
			fn(values, previousValues ?? []);
		}, options);
	});
}
function resourcePre$1(source, fetcher, options) {
	return runResource$1(source, fetcher, options, (fn, options) => {
		const sources = Array.isArray(source) ? source : [source];
		const getter = () => sources.map((s) => s());
		watch$1.pre(getter, (values, previousValues) => {
			fn(values, previousValues ?? []);
		}, options);
	});
}
resource$1.pre = resourcePre$1;
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/on-destroy-effect.svelte.js
function onDestroyEffect(fn) {
	user_effect(() => {
		return () => {
			fn();
		};
	});
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/on-mount-effect.svelte.js
function onMountEffect(fn) {
	user_effect(() => {
		return untrack(() => fn());
	});
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/after-sleep.js
/**
* A utility function that executes a callback after a specified number of milliseconds.
*/
function afterSleep(ms, cb) {
	return setTimeout(cb, ms);
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/after-tick.js
function afterTick(fn) {
	tick().then(fn);
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/dom.js
var ELEMENT_NODE = 1;
var DOCUMENT_NODE = 9;
var DOCUMENT_FRAGMENT_NODE = 11;
function isHTMLElement$2(node) {
	return isObject(node) && node.nodeType === ELEMENT_NODE && typeof node.nodeName === "string";
}
function isDocument(node) {
	return isObject(node) && node.nodeType === DOCUMENT_NODE;
}
function isWindow(node) {
	return isObject(node) && node.constructor?.name === "VisualViewport";
}
function isNode$1(node) {
	return isObject(node) && node.nodeType !== void 0;
}
function isShadowRoot$1(node) {
	return isNode$1(node) && node.nodeType === DOCUMENT_FRAGMENT_NODE && "host" in node;
}
function contains(parent, child) {
	if (!parent || !child) return false;
	if (!isHTMLElement$2(parent) || !isHTMLElement$2(child)) return false;
	const rootNode = child.getRootNode?.();
	if (parent === child) return true;
	if (parent.contains(child)) return true;
	if (rootNode && isShadowRoot$1(rootNode)) {
		let next = child;
		while (next) {
			if (parent === next) return true;
			next = next.parentNode || next.host;
		}
	}
	return false;
}
function getDocument(node) {
	if (isDocument(node)) return node;
	if (isWindow(node)) return node.document;
	return node?.ownerDocument ?? document;
}
function getWindow$1(node) {
	if (isShadowRoot$1(node)) return getWindow$1(node.host);
	if (isDocument(node)) return node.defaultView ?? window;
	if (isHTMLElement$2(node)) return node.ownerDocument?.defaultView ?? window;
	return window;
}
function getActiveElement$1(rootNode) {
	let activeElement = rootNode.activeElement;
	while (activeElement?.shadowRoot) {
		const el = activeElement.shadowRoot.activeElement;
		if (el === activeElement) break;
		else activeElement = el;
	}
	return activeElement;
}
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/dom-context.svelte.js
var DOMContext = class {
	element;
	#root = user_derived(() => {
		if (!this.element.current) return document;
		return this.element.current.getRootNode() ?? document;
	});
	get root() {
		return get$2(this.#root);
	}
	set root(value) {
		set(this.#root, value);
	}
	constructor(element) {
		if (typeof element === "function") this.element = boxWith(element);
		else this.element = element;
	}
	getDocument = () => {
		return getDocument(this.root);
	};
	getWindow = () => {
		return this.getDocument().defaultView ?? window;
	};
	getActiveElement = () => {
		return getActiveElement$1(this.root);
	};
	isActiveElement = (node) => {
		return node === this.getActiveElement();
	};
	getElementById(id) {
		return this.root.getElementById(id);
	}
	querySelector = (selector) => {
		if (!this.root) return null;
		return this.root.querySelector(selector);
	};
	querySelectorAll = (selector) => {
		if (!this.root) return [];
		return this.root.querySelectorAll(selector);
	};
	setTimeout = (callback, delay) => {
		return this.getWindow().setTimeout(callback, delay);
	};
	clearTimeout = (timeoutId) => {
		return this.getWindow().clearTimeout(timeoutId);
	};
};
//#endregion
//#region node_modules/svelte-toolbelt/dist/utils/attach-ref.js
/**
* Creates a Svelte Attachment that attaches a DOM element to a ref.
* The ref can be either a WritableBox or a callback function.
*
* @param ref - Either a WritableBox to store the element in, or a callback function that receives the element
* @param onChange - Optional callback that fires when the ref changes
* @returns An object with a spreadable attachment key that should be spread onto the element
*
* @example
* // Using with WritableBox
* const ref = box<HTMLDivElement | null>(null);
* <div {...attachRef(ref)}>Content</div>
*
* @example
* // Using with callback
* <div {...attachRef((node) => myNode = node)}>Content</div>
*
* @example
* // Using with onChange
* <div {...attachRef(ref, (node) => console.log(node))}>Content</div>
*/
function attachRef(ref, onChange) {
	return { [createAttachmentKey()]: (node) => {
		if (isBox(ref)) {
			ref.current = node;
			untrack(() => onChange?.(node));
			return () => {
				if ("isConnected" in node && node.isConnected) return;
				ref.current = null;
				onChange?.(null);
			};
		}
		ref(node);
		untrack(() => onChange?.(node));
		return () => {
			if ("isConnected" in node && node.isConnected) return;
			ref(null);
			onChange?.(null);
		};
	} };
}
//#endregion
//#region node_modules/bits-ui/dist/internal/attrs.js
function boolToStr(condition) {
	return condition ? "true" : "false";
}
function boolToStrTrueOrUndef(condition) {
	return condition ? "true" : void 0;
}
function boolToEmptyStrOrUndef(condition) {
	return condition ? "" : void 0;
}
function boolToTrueOrUndef(condition) {
	return condition ? true : void 0;
}
function getDataOpenClosed(condition) {
	return condition ? "open" : "closed";
}
function getDataChecked(condition) {
	return condition ? "checked" : "unchecked";
}
function getDataTransitionAttrs(state) {
	if (state === "starting") return { "data-starting-style": "" };
	if (state === "ending") return { "data-ending-style": "" };
	return {};
}
function getAriaChecked(checked, indeterminate) {
	if (indeterminate) return "mixed";
	return checked ? "true" : "false";
}
var BitsAttrs = class {
	#variant;
	#prefix;
	attrs;
	constructor(config) {
		this.#variant = config.getVariant ? config.getVariant() : null;
		this.#prefix = this.#variant ? `data-${this.#variant}-` : `data-${config.component}-`;
		this.getAttr = this.getAttr.bind(this);
		this.selector = this.selector.bind(this);
		this.attrs = Object.fromEntries(config.parts.map((part) => [part, this.getAttr(part)]));
	}
	getAttr(part, variantOverride) {
		if (variantOverride) return `data-${variantOverride}-${part}`;
		return `${this.#prefix}${part}`;
	}
	selector(part, variantOverride) {
		return `[${this.getAttr(part, variantOverride)}]`;
	}
};
function createBitsAttrs(config) {
	const bitsAttrs = new BitsAttrs(config);
	return {
		...bitsAttrs.attrs,
		selector: bitsAttrs.selector,
		getAttr: bitsAttrs.getAttr
	};
}
var ARROW_DOWN = "ArrowDown";
var ARROW_LEFT = "ArrowLeft";
var ARROW_RIGHT = "ArrowRight";
var ARROW_UP = "ArrowUp";
var CAPS_LOCK = "CapsLock";
var CONTROL = "Control";
var ENTER = "Enter";
var ESCAPE = "Escape";
var HOME = "Home";
var META = "Meta";
var PAGE_DOWN = "PageDown";
var PAGE_UP = "PageUp";
var SHIFT = "Shift";
//#endregion
//#region node_modules/bits-ui/dist/internal/locale.js
/**
* Detects the text direction in the element.
* @returns {Direction} The text direction ('ltr' for left-to-right or 'rtl' for right-to-left).
*/
function getElemDirection(elem) {
	return window.getComputedStyle(elem).getPropertyValue("direction");
}
//#endregion
//#region node_modules/bits-ui/dist/internal/get-directional-keys.js
var FIRST_KEYS = [
	ARROW_DOWN,
	PAGE_UP,
	HOME
];
var LAST_KEYS = [
	ARROW_UP,
	PAGE_DOWN,
	"End"
];
[...FIRST_KEYS, ...LAST_KEYS];
/**
* A utility function that returns the next key based on the direction and orientation.
*/
function getNextKey(dir = "ltr", orientation = "horizontal") {
	return {
		horizontal: dir === "rtl" ? ARROW_LEFT : ARROW_RIGHT,
		vertical: ARROW_DOWN
	}[orientation];
}
/**
* A utility function that returns the previous key based on the direction and orientation.
*/
function getPrevKey(dir = "ltr", orientation = "horizontal") {
	return {
		horizontal: dir === "rtl" ? ARROW_RIGHT : ARROW_LEFT,
		vertical: ARROW_UP
	}[orientation];
}
/**
* A utility function that returns the next and previous keys based on the direction
* and orientation.
*/
function getDirectionalKeys(dir = "ltr", orientation = "horizontal") {
	if (!["ltr", "rtl"].includes(dir)) dir = "ltr";
	if (!["horizontal", "vertical"].includes(orientation)) orientation = "horizontal";
	return {
		nextKey: getNextKey(dir, orientation),
		prevKey: getPrevKey(dir, orientation)
	};
}
//#endregion
//#region node_modules/bits-ui/dist/internal/is.js
var isBrowser$1 = typeof document !== "undefined";
var isIOS = getIsIOS();
function getIsIOS() {
	return isBrowser$1 && window?.navigator?.userAgent && (/iP(ad|hone|od)/.test(window.navigator.userAgent) || window?.navigator?.maxTouchPoints > 2 && /iPad|Macintosh/.test(window?.navigator.userAgent));
}
function isHTMLElement$1(element) {
	return element instanceof HTMLElement;
}
function isElement$1(element) {
	return element instanceof Element;
}
function isElementOrSVGElement(element) {
	return element instanceof Element || element instanceof SVGElement;
}
function isFocusVisible(element) {
	return element.matches(":focus-visible");
}
function isNotNull(value) {
	return value !== null;
}
//#endregion
//#region node_modules/bits-ui/dist/internal/roving-focus-group.js
var RovingFocusGroup = class {
	#opts;
	#currentTabStopId = box(null);
	constructor(opts) {
		this.#opts = opts;
	}
	getCandidateNodes() {
		if (!this.#opts.rootNode.current) return [];
		if (this.#opts.candidateSelector) return Array.from(this.#opts.rootNode.current.querySelectorAll(this.#opts.candidateSelector));
		else if (this.#opts.candidateAttr) return Array.from(this.#opts.rootNode.current.querySelectorAll(`[${this.#opts.candidateAttr}]:not([data-disabled])`));
		return [];
	}
	focusFirstCandidate() {
		const items = this.getCandidateNodes();
		if (!items.length) return;
		items[0]?.focus();
	}
	handleKeydown(node, e, both = false) {
		const rootNode = this.#opts.rootNode.current;
		if (!rootNode || !node) return;
		const items = this.getCandidateNodes();
		if (!items.length) return;
		const currentIndex = items.indexOf(node);
		const { nextKey, prevKey } = getDirectionalKeys(getElemDirection(rootNode), this.#opts.orientation.current);
		const loop = this.#opts.loop.current;
		const keyToIndex = {
			[nextKey]: currentIndex + 1,
			[prevKey]: currentIndex - 1,
			[HOME]: 0,
			["End"]: items.length - 1
		};
		if (both) {
			const altNextKey = nextKey === "ArrowDown" ? ARROW_RIGHT : ARROW_DOWN;
			const altPrevKey = prevKey === "ArrowUp" ? ARROW_LEFT : ARROW_UP;
			keyToIndex[altNextKey] = currentIndex + 1;
			keyToIndex[altPrevKey] = currentIndex - 1;
		}
		let itemIndex = keyToIndex[e.key];
		if (itemIndex === void 0) return;
		e.preventDefault();
		if (itemIndex < 0 && loop) itemIndex = items.length - 1;
		else if (itemIndex === items.length && loop) itemIndex = 0;
		const itemToFocus = items[itemIndex];
		if (!itemToFocus) return;
		itemToFocus.focus();
		this.#currentTabStopId.current = itemToFocus.id;
		this.#opts.onCandidateFocus?.(itemToFocus);
		return itemToFocus;
	}
	getTabIndex(node) {
		const items = this.getCandidateNodes();
		const anyActive = this.#currentTabStopId.current !== null;
		if (node && !anyActive && items[0] === node) {
			this.#currentTabStopId.current = node.id;
			return 0;
		} else if (node?.id === this.#currentTabStopId.current) return 0;
		return -1;
	}
	setCurrentTabStopId(id) {
		this.#currentTabStopId.current = id;
	}
	focusCurrentTabStop() {
		const currentTabStopId = this.#currentTabStopId.current;
		if (!currentTabStopId) return;
		const currentTabStop = this.#opts.rootNode.current?.querySelector(`#${currentTabStopId}`);
		if (!currentTabStop || !isHTMLElement$1(currentTabStop)) return;
		currentTabStop.focus();
	}
};
//#endregion
//#region node_modules/bits-ui/dist/internal/animations-complete.js
var AnimationsComplete = class {
	#opts;
	#currentFrame = null;
	#observer = null;
	#runId = 0;
	constructor(opts) {
		this.#opts = opts;
		onDestroyEffect(() => this.#cleanup());
	}
	#cleanup() {
		if (this.#currentFrame !== null) {
			window.cancelAnimationFrame(this.#currentFrame);
			this.#currentFrame = null;
		}
		this.#observer?.disconnect();
		this.#observer = null;
		this.#runId++;
	}
	run(fn) {
		this.#cleanup();
		const node = this.#opts.ref.current;
		if (!node) return;
		if (typeof node.getAnimations !== "function") {
			this.#executeCallback(fn);
			return;
		}
		const runId = this.#runId;
		const executeIfCurrent = () => {
			if (runId !== this.#runId) return;
			this.#executeCallback(fn);
		};
		const waitForAnimations = () => {
			if (runId !== this.#runId) return;
			const animations = node.getAnimations();
			if (animations.length === 0) {
				executeIfCurrent();
				return;
			}
			Promise.all(animations.map((animation) => animation.finished)).then(() => {
				executeIfCurrent();
			}).catch(() => {
				if (runId !== this.#runId) return;
				if (node.getAnimations().some((animation) => animation.pending || animation.playState !== "finished")) {
					waitForAnimations();
					return;
				}
				executeIfCurrent();
			});
		};
		const requestWaitForAnimations = () => {
			this.#currentFrame = window.requestAnimationFrame(() => {
				this.#currentFrame = null;
				waitForAnimations();
			});
		};
		if (!this.#opts.afterTick.current) {
			requestWaitForAnimations();
			return;
		}
		this.#currentFrame = window.requestAnimationFrame(() => {
			this.#currentFrame = null;
			const startingStyleAttr = "data-starting-style";
			if (!node.hasAttribute(startingStyleAttr)) {
				requestWaitForAnimations();
				return;
			}
			this.#observer = new MutationObserver(() => {
				if (runId !== this.#runId) return;
				if (node.hasAttribute(startingStyleAttr)) return;
				this.#observer?.disconnect();
				this.#observer = null;
				requestWaitForAnimations();
			});
			this.#observer.observe(node, {
				attributes: true,
				attributeFilter: [startingStyleAttr]
			});
		});
	}
	#executeCallback(fn) {
		const execute = () => {
			fn();
		};
		if (this.#opts.afterTick) afterTick(execute);
		else execute();
	}
};
//#endregion
//#region node_modules/bits-ui/dist/internal/presence-manager.svelte.js
var PresenceManager = class {
	#opts;
	#enabled;
	#afterAnimations;
	#shouldRender = state$1(false);
	#transitionStatus = state$1(void 0);
	#hasMounted = false;
	#transitionFrame = null;
	constructor(opts) {
		this.#opts = opts;
		set(this.#shouldRender, opts.open.current, true);
		this.#enabled = opts.enabled ?? true;
		this.#afterAnimations = new AnimationsComplete({
			ref: this.#opts.ref,
			afterTick: this.#opts.open
		});
		onDestroyEffect(() => this.#clearTransitionFrame());
		watch$1(() => this.#opts.open.current, (isOpen) => {
			if (!this.#hasMounted) {
				this.#hasMounted = true;
				return;
			}
			this.#clearTransitionFrame();
			if (!isOpen && this.#opts.shouldSkipExitAnimation?.()) {
				set(this.#shouldRender, false);
				set(this.#transitionStatus, void 0);
				this.#opts.onComplete?.();
				return;
			}
			if (isOpen) set(this.#shouldRender, true);
			set(this.#transitionStatus, isOpen ? "starting" : "ending", true);
			if (isOpen) this.#transitionFrame = window.requestAnimationFrame(() => {
				this.#transitionFrame = null;
				if (this.#opts.open.current) set(this.#transitionStatus, void 0);
			});
			if (!this.#enabled) {
				if (!isOpen) set(this.#shouldRender, false);
				set(this.#transitionStatus, void 0);
				this.#opts.onComplete?.();
				return;
			}
			this.#afterAnimations.run(() => {
				if (isOpen === this.#opts.open.current) {
					if (!this.#opts.open.current) set(this.#shouldRender, false);
					set(this.#transitionStatus, void 0);
					this.#opts.onComplete?.();
				}
			});
		});
	}
	get shouldRender() {
		return get$2(this.#shouldRender);
	}
	get transitionStatus() {
		return get$2(this.#transitionStatus);
	}
	#clearTransitionFrame() {
		if (this.#transitionFrame === null) return;
		window.cancelAnimationFrame(this.#transitionFrame);
		this.#transitionFrame = null;
	}
};
//#endregion
//#region node_modules/bits-ui/dist/internal/noop.js
/**
* A no operation function (does nothing)
*/
function noop() {}
//#endregion
//#region node_modules/bits-ui/dist/internal/create-id.js
function createId(prefixOrUid, uid) {
	if (uid === void 0) return `bits-${prefixOrUid}`;
	return `bits-${prefixOrUid}-${uid}`;
}
//#endregion
//#region node_modules/bits-ui/dist/bits/dialog/dialog.svelte.js
var dialogAttrs = createBitsAttrs({
	component: "dialog",
	parts: [
		"content",
		"trigger",
		"overlay",
		"title",
		"description",
		"close",
		"cancel",
		"action"
	]
});
var DialogRootContext = new Context$1("Dialog.Root | AlertDialog.Root");
var DialogRootState = class DialogRootState {
	static create(opts) {
		const parent = DialogRootContext.getOr(null);
		return DialogRootContext.set(new DialogRootState(opts, parent));
	}
	opts;
	#triggerNode = state$1(null);
	get triggerNode() {
		return get$2(this.#triggerNode);
	}
	set triggerNode(value) {
		set(this.#triggerNode, value, true);
	}
	#contentNode = state$1(null);
	get contentNode() {
		return get$2(this.#contentNode);
	}
	set contentNode(value) {
		set(this.#contentNode, value, true);
	}
	#overlayNode = state$1(null);
	get overlayNode() {
		return get$2(this.#overlayNode);
	}
	set overlayNode(value) {
		set(this.#overlayNode, value, true);
	}
	#descriptionNode = state$1(null);
	get descriptionNode() {
		return get$2(this.#descriptionNode);
	}
	set descriptionNode(value) {
		set(this.#descriptionNode, value, true);
	}
	#contentId = state$1(void 0);
	get contentId() {
		return get$2(this.#contentId);
	}
	set contentId(value) {
		set(this.#contentId, value, true);
	}
	#titleId = state$1(void 0);
	get titleId() {
		return get$2(this.#titleId);
	}
	set titleId(value) {
		set(this.#titleId, value, true);
	}
	#triggerId = state$1(void 0);
	get triggerId() {
		return get$2(this.#triggerId);
	}
	set triggerId(value) {
		set(this.#triggerId, value, true);
	}
	#descriptionId = state$1(void 0);
	get descriptionId() {
		return get$2(this.#descriptionId);
	}
	set descriptionId(value) {
		set(this.#descriptionId, value, true);
	}
	#cancelNode = state$1(null);
	get cancelNode() {
		return get$2(this.#cancelNode);
	}
	set cancelNode(value) {
		set(this.#cancelNode, value, true);
	}
	#nestedOpenCount = state$1(0);
	get nestedOpenCount() {
		return get$2(this.#nestedOpenCount);
	}
	set nestedOpenCount(value) {
		set(this.#nestedOpenCount, value, true);
	}
	depth;
	parent;
	contentPresence;
	overlayPresence;
	constructor(opts, parent) {
		this.opts = opts;
		this.parent = parent;
		this.depth = parent ? parent.depth + 1 : 0;
		this.handleOpen = this.handleOpen.bind(this);
		this.handleClose = this.handleClose.bind(this);
		this.contentPresence = new PresenceManager({
			ref: boxWith(() => this.contentNode),
			open: this.opts.open,
			enabled: true,
			onComplete: () => {
				this.opts.onOpenChangeComplete.current(this.opts.open.current);
			}
		});
		this.overlayPresence = new PresenceManager({
			ref: boxWith(() => this.overlayNode),
			open: this.opts.open,
			enabled: true
		});
		watch$1(() => this.opts.open.current, (isOpen) => {
			if (!this.parent) return;
			if (isOpen) this.parent.incrementNested();
			else this.parent.decrementNested();
		}, { lazy: true });
		onDestroyEffect(() => {
			if (this.opts.open.current) this.parent?.decrementNested();
		});
	}
	handleOpen() {
		if (this.opts.open.current) return;
		this.opts.open.current = true;
	}
	handleClose() {
		if (!this.opts.open.current) return;
		this.opts.open.current = false;
	}
	getBitsAttr = (part) => {
		return dialogAttrs.getAttr(part, this.opts.variant.current);
	};
	incrementNested() {
		this.nestedOpenCount++;
		this.parent?.incrementNested();
	}
	decrementNested() {
		if (this.nestedOpenCount === 0) return;
		this.nestedOpenCount--;
		this.parent?.decrementNested();
	}
	#sharedProps = user_derived(() => ({ "data-state": getDataOpenClosed(this.opts.open.current) }));
	get sharedProps() {
		return get$2(this.#sharedProps);
	}
	set sharedProps(value) {
		set(this.#sharedProps, value);
	}
};
var DialogCloseState = class DialogCloseState {
	static create(opts) {
		return new DialogCloseState(opts, DialogRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.attachment = attachRef(this.opts.ref);
		this.onclick = this.onclick.bind(this);
		this.onkeydown = this.onkeydown.bind(this);
	}
	onclick(e) {
		if (this.opts.disabled.current) return;
		if (e.button > 0) return;
		this.root.handleClose();
	}
	onkeydown(e) {
		if (this.opts.disabled.current) return;
		if (e.key === " " || e.key === "Enter") {
			e.preventDefault();
			this.root.handleClose();
		}
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		[this.root.getBitsAttr(this.opts.variant.current)]: "",
		onclick: this.onclick,
		onkeydown: this.onkeydown,
		disabled: this.opts.disabled.current ? true : void 0,
		tabindex: 0,
		...this.root.sharedProps,
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
var DialogTitleState = class DialogTitleState {
	static create(opts) {
		return new DialogTitleState(opts, DialogRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.root.titleId = this.opts.id.current;
		this.attachment = attachRef(this.opts.ref);
		watch$1.pre(() => this.opts.id.current, (id) => {
			this.root.titleId = id;
		});
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		role: "heading",
		"aria-level": this.opts.level.current,
		[this.root.getBitsAttr("title")]: "",
		...this.root.sharedProps,
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
var DialogDescriptionState = class DialogDescriptionState {
	static create(opts) {
		return new DialogDescriptionState(opts, DialogRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.root.descriptionId = this.opts.id.current;
		this.attachment = attachRef(this.opts.ref, (v) => {
			this.root.descriptionNode = v;
		});
		watch$1.pre(() => this.opts.id.current, (id) => {
			this.root.descriptionId = id;
		});
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		[this.root.getBitsAttr("description")]: "",
		...this.root.sharedProps,
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
var DialogContentState = class DialogContentState {
	static create(opts) {
		return new DialogContentState(opts, DialogRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.attachment = attachRef(this.opts.ref, (v) => {
			this.root.contentNode = v;
			this.root.contentId = v?.id;
		});
	}
	#snippetProps = user_derived(() => ({ open: this.root.opts.open.current }));
	get snippetProps() {
		return get$2(this.#snippetProps);
	}
	set snippetProps(value) {
		set(this.#snippetProps, value);
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		role: this.root.opts.variant.current === "alert-dialog" ? "alertdialog" : "dialog",
		"aria-modal": "true",
		"aria-describedby": this.root.descriptionId,
		"aria-labelledby": this.root.titleId,
		[this.root.getBitsAttr("content")]: "",
		style: {
			pointerEvents: "auto",
			outline: this.root.opts.variant.current === "alert-dialog" ? "none" : void 0,
			"--bits-dialog-depth": this.root.depth,
			"--bits-dialog-nested-count": this.root.nestedOpenCount,
			contain: "layout style"
		},
		tabindex: this.root.opts.variant.current === "alert-dialog" ? -1 : void 0,
		"data-nested-open": boolToEmptyStrOrUndef(this.root.nestedOpenCount > 0),
		"data-nested": boolToEmptyStrOrUndef(this.root.parent !== null),
		...getDataTransitionAttrs(this.root.contentPresence.transitionStatus),
		...this.root.sharedProps,
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
	get shouldRender() {
		return this.root.contentPresence.shouldRender;
	}
};
var DialogOverlayState = class DialogOverlayState {
	static create(opts) {
		return new DialogOverlayState(opts, DialogRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.attachment = attachRef(this.opts.ref, (v) => this.root.overlayNode = v);
	}
	#snippetProps = user_derived(() => ({ open: this.root.opts.open.current }));
	get snippetProps() {
		return get$2(this.#snippetProps);
	}
	set snippetProps(value) {
		set(this.#snippetProps, value);
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		[this.root.getBitsAttr("overlay")]: "",
		style: {
			pointerEvents: "auto",
			"--bits-dialog-depth": this.root.depth,
			"--bits-dialog-nested-count": this.root.nestedOpenCount
		},
		"data-nested-open": boolToEmptyStrOrUndef(this.root.nestedOpenCount > 0),
		"data-nested": boolToEmptyStrOrUndef(this.root.parent !== null),
		...getDataTransitionAttrs(this.root.overlayPresence.transitionStatus),
		...this.root.sharedProps,
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
	get shouldRender() {
		return this.root.overlayPresence.shouldRender;
	}
};
var AlertDialogCancelState = class AlertDialogCancelState {
	static create(opts) {
		return new AlertDialogCancelState(opts, DialogRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.attachment = attachRef(this.opts.ref, (v) => this.root.cancelNode = v);
		this.onclick = this.onclick.bind(this);
		this.onkeydown = this.onkeydown.bind(this);
	}
	onclick(e) {
		if (this.opts.disabled.current) return;
		if (e.button > 0) return;
		this.root.handleClose();
	}
	onkeydown(e) {
		if (this.opts.disabled.current) return;
		if (e.key === " " || e.key === "Enter") {
			e.preventDefault();
			this.root.handleClose();
		}
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		[this.root.getBitsAttr("cancel")]: "",
		onclick: this.onclick,
		onkeydown: this.onkeydown,
		tabindex: 0,
		...this.root.sharedProps,
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
//#endregion
//#region node_modules/bits-ui/dist/bits/dialog/components/dialog-title.svelte
var root_2$16 = from_html(`<div><!></div>`);
function Dialog_title($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), ref = prop($$props, "ref", 15, null), level = prop($$props, "level", 3, 2), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"ref",
		"child",
		"children",
		"level"
	]);
	const titleState = DialogTitleState.create({
		id: boxWith(() => id()),
		level: boxWith(() => level()),
		ref: boxWith(() => ref(), (v) => ref(v))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, titleState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.child, () => ({ props: get$2(mergedProps) }));
		append($$anchor, fragment_1);
	};
	var alternate = ($$anchor) => {
		var div = root_2$16();
		attribute_effect(div, () => ({ ...get$2(mergedProps) }));
		snippet(child(div), () => $$props.children ?? noop$1);
		reset(div);
		append($$anchor, div);
	};
	if_block(node, ($$render) => {
		if ($$props.child) $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/portal/portal-consumer.svelte
function Portal_consumer($$anchor, $$props) {
	var fragment = comment();
	key(first_child(fragment), () => $$props.children, ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.children ?? noop$1);
		append($$anchor, fragment_1);
	});
	append($$anchor, fragment);
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/config/bits-config.js
var BitsConfigContext = new Context$1("BitsConfig");
/**
* Gets the current Bits UI configuration state from the context.
*
* Returns a default configuration (where all values are `undefined`) if no configuration is found.
*/
function getBitsConfig() {
	const fallback = new BitsConfigState(null, {});
	return BitsConfigContext.getOr(fallback).opts;
}
/**
* Configuration state that inherits from parent configurations.
*
* @example
* Config resolution:
* ```
* Level 1: { defaultPortalTo: "#some-element", theme: "dark" }
* Level 2: { spacing: "large" } // inherits defaultPortalTo="#some-element", theme="dark"
* Level 3: { theme: "light" }   // inherits defaultPortalTo="#some-element", spacing="large", overrides theme="light"
* ```
*/
var BitsConfigState = class {
	opts;
	constructor(parent, opts) {
		const resolveConfigOption = createConfigResolver(parent, opts);
		this.opts = {
			defaultPortalTo: resolveConfigOption((config) => config.defaultPortalTo),
			defaultLocale: resolveConfigOption((config) => config.defaultLocale)
		};
	}
};
/**
* Returns a config resolver that resolves a given config option's value.
*
* The resolver creates reactive boxes that resolve config option values using this priority:
* 1. Current level's value (if defined)
* 2. Parent level's value (if defined and current is undefined)
* 3. `undefined` (if no value is found in either parent or child)
*
* @param parent - Parent configuration state (null if this is root level)
* @param currentOpts - Current level's configuration options
*
* @example
* ```typescript
* // Given this hierarchy:
* // Root: { defaultPortalTo: "#some-element" }
* // Child: { someOtherProp: "value" } // no defaultPortalTo specified
*
* const resolveConfigOption = createConfigResolver(parent, opts);
* const portalTo = resolveConfigOption(config => config.defaultPortalTo);
*
* // portalTo.current === "#some-element" (inherited from parent)
* // even when child didn't specify `defaultPortalTo`
* ```
*/
function createConfigResolver(parent, currentOpts) {
	return (getter) => {
		return boxWith(() => {
			const value = getter(currentOpts)?.current;
			if (value !== void 0) return value;
			if (parent === null) return void 0;
			return getter(parent.opts)?.current;
		});
	};
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/config/prop-resolvers.js
/**
* Creates a generic prop resolver that follows a standard priority chain:
* 1. The getter's prop value (if defined)
* 2. The config default value (if no getter prop value is defined)
* 3. The fallback value (if no config value found)
*/
function createPropResolver(configOption, fallback) {
	return (getProp) => {
		const config = getBitsConfig();
		return boxWith(() => {
			const propValue = getProp();
			if (propValue !== void 0) return propValue;
			const option = configOption(config).current;
			if (option !== void 0) return option;
			return fallback;
		});
	};
}
createPropResolver((config) => config.defaultLocale, "en");
/**
* Resolves a portal's `to` value using the prop, the config default, or a fallback.
*
* Default value: `"body"`
*/
var resolvePortalToProp = createPropResolver((config) => config.defaultPortalTo, "body");
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/portal/portal.svelte
function Portal($$anchor, $$props) {
	push($$props, true);
	const to = resolvePortalToProp(() => $$props.to);
	const context = getAllContexts();
	let target = user_derived(getTarget);
	function getTarget() {
		if (!isBrowser$1 || $$props.disabled) return null;
		let localTarget = null;
		if (typeof to.current === "string") localTarget = document.querySelector(to.current);
		else localTarget = to.current;
		return localTarget;
	}
	let instance;
	function unmountInstance() {
		if (instance) {
			unmount(instance);
			instance = null;
		}
	}
	watch$1([() => get$2(target), () => $$props.disabled], ([target, disabled]) => {
		if (!target || disabled) {
			unmountInstance();
			return;
		}
		instance = mount(Portal_consumer, {
			target,
			props: { children: $$props.children },
			context
		});
		return () => {
			unmountInstance();
		};
	});
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.children ?? noop$1);
		append($$anchor, fragment_1);
	};
	if_block(node, ($$render) => {
		if ($$props.disabled) $$render(consequent);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/internal/events.js
/**
* Creates a typed event dispatcher and listener pair for custom events
* @template T - The type of data that will be passed in the event detail
* @param eventName - The name of the custom event
* @param options - CustomEvent options (bubbles, cancelable, etc.)
*/
var CustomEventDispatcher = class {
	eventName;
	options;
	constructor(eventName, options = {
		bubbles: true,
		cancelable: true
	}) {
		this.eventName = eventName;
		this.options = options;
	}
	createEvent(detail) {
		return new CustomEvent(this.eventName, {
			...this.options,
			detail
		});
	}
	dispatch(element, detail) {
		const event = this.createEvent(detail);
		element.dispatchEvent(event);
		return event;
	}
	listen(element, callback, options) {
		const handler = (event) => {
			callback(event);
		};
		return on(element, this.eventName, handler, options);
	}
};
//#endregion
//#region node_modules/bits-ui/dist/internal/debounce.js
function debounce$1(fn, wait = 500) {
	let timeout = null;
	const debounced = (...args) => {
		if (timeout !== null) clearTimeout(timeout);
		timeout = setTimeout(() => {
			fn(...args);
		}, wait);
	};
	debounced.destroy = () => {
		if (timeout !== null) {
			clearTimeout(timeout);
			timeout = null;
		}
	};
	return debounced;
}
//#endregion
//#region node_modules/bits-ui/dist/internal/elements.js
function isOrContainsTarget(node, target) {
	return node === target || node.contains(target);
}
function getOwnerDocument(el) {
	return el?.ownerDocument ?? document;
}
//#endregion
//#region node_modules/bits-ui/dist/internal/dom.js
function getFirstNonCommentChild(element) {
	if (!element) return null;
	for (const child of element.childNodes) if (child.nodeType !== Node.COMMENT_NODE) return child;
	return null;
}
/**
* Determines if the click event truly occurred outside the content node.
* This was added to handle password managers and other elements that may be injected
* into the DOM but visually appear inside the content.
*/
function isClickTrulyOutside(event, contentNode) {
	const { clientX, clientY } = event;
	const rect = contentNode.getBoundingClientRect();
	return clientX < rect.left || clientX > rect.right || clientY < rect.top || clientY > rect.bottom;
}
//#endregion
//#region node_modules/tabbable/dist/index.esm.js
/*!
* tabbable 6.4.0
* @license MIT, https://github.com/focus-trap/tabbable/blob/master/LICENSE
*/
var candidateSelectors = [
	"input:not([inert]):not([inert] *)",
	"select:not([inert]):not([inert] *)",
	"textarea:not([inert]):not([inert] *)",
	"a[href]:not([inert]):not([inert] *)",
	"button:not([inert]):not([inert] *)",
	"[tabindex]:not(slot):not([inert]):not([inert] *)",
	"audio[controls]:not([inert]):not([inert] *)",
	"video[controls]:not([inert]):not([inert] *)",
	"[contenteditable]:not([contenteditable=\"false\"]):not([inert]):not([inert] *)",
	"details>summary:first-of-type:not([inert]):not([inert] *)",
	"details:not([inert]):not([inert] *)"
];
var candidateSelector = /* @__PURE__ */ candidateSelectors.join(",");
var NoElement = typeof Element === "undefined";
var matches = NoElement ? function() {} : Element.prototype.matches || Element.prototype.msMatchesSelector || Element.prototype.webkitMatchesSelector;
var getRootNode = !NoElement && Element.prototype.getRootNode ? function(element) {
	var _element$getRootNode;
	return element === null || element === void 0 ? void 0 : (_element$getRootNode = element.getRootNode) === null || _element$getRootNode === void 0 ? void 0 : _element$getRootNode.call(element);
} : function(element) {
	return element === null || element === void 0 ? void 0 : element.ownerDocument;
};
/**
* Determines if a node is inert or in an inert ancestor.
* @param {Node} [node]
* @param {boolean} [lookUp] If true and `node` is not inert, looks up at ancestors to
*  see if any of them are inert. If false, only `node` itself is considered.
* @returns {boolean} True if inert itself or by way of being in an inert ancestor.
*  False if `node` is falsy.
*/
var _isInert = function isInert(node, lookUp) {
	var _node$getAttribute;
	if (lookUp === void 0) lookUp = true;
	var inertAtt = node === null || node === void 0 ? void 0 : (_node$getAttribute = node.getAttribute) === null || _node$getAttribute === void 0 ? void 0 : _node$getAttribute.call(node, "inert");
	return inertAtt === "" || inertAtt === "true" || lookUp && node && (typeof node.closest === "function" ? node.closest("[inert]") : _isInert(node.parentNode));
};
/**
* Determines if a node's content is editable.
* @param {Element} [node]
* @returns True if it's content-editable; false if it's not or `node` is falsy.
*/
var isContentEditable = function isContentEditable(node) {
	var _node$getAttribute2;
	var attValue = node === null || node === void 0 ? void 0 : (_node$getAttribute2 = node.getAttribute) === null || _node$getAttribute2 === void 0 ? void 0 : _node$getAttribute2.call(node, "contenteditable");
	return attValue === "" || attValue === "true";
};
/**
* @param {Element} el container to check in
* @param {boolean} includeContainer add container to check
* @param {(node: Element) => boolean} filter filter candidates
* @returns {Element[]}
*/
var getCandidates = function getCandidates(el, includeContainer, filter) {
	if (_isInert(el)) return [];
	var candidates = Array.prototype.slice.apply(el.querySelectorAll(candidateSelector));
	if (includeContainer && matches.call(el, candidateSelector)) candidates.unshift(el);
	candidates = candidates.filter(filter);
	return candidates;
};
/**
* @callback GetShadowRoot
* @param {Element} element to check for shadow root
* @returns {ShadowRoot|boolean} ShadowRoot if available or boolean indicating if a shadowRoot is attached but not available.
*/
/**
* @callback ShadowRootFilter
* @param {Element} shadowHostNode the element which contains shadow content
* @returns {boolean} true if a shadow root could potentially contain valid candidates.
*/
/**
* @typedef {Object} CandidateScope
* @property {Element} scopeParent contains inner candidates
* @property {Element[]} candidates list of candidates found in the scope parent
*/
/**
* @typedef {Object} IterativeOptions
* @property {GetShadowRoot|boolean} getShadowRoot true if shadow support is enabled; falsy if not;
*  if a function, implies shadow support is enabled and either returns the shadow root of an element
*  or a boolean stating if it has an undisclosed shadow root
* @property {(node: Element) => boolean} filter filter candidates
* @property {boolean} flatten if true then result will flatten any CandidateScope into the returned list
* @property {ShadowRootFilter} shadowRootFilter filter shadow roots;
*/
/**
* @param {Element[]} elements list of element containers to match candidates from
* @param {boolean} includeContainer add container list to check
* @param {IterativeOptions} options
* @returns {Array.<Element|CandidateScope>}
*/
var _getCandidatesIteratively = function getCandidatesIteratively(elements, includeContainer, options) {
	var candidates = [];
	var elementsToCheck = Array.from(elements);
	while (elementsToCheck.length) {
		var element = elementsToCheck.shift();
		if (_isInert(element, false)) continue;
		if (element.tagName === "SLOT") {
			var assigned = element.assignedElements();
			var nestedCandidates = _getCandidatesIteratively(assigned.length ? assigned : element.children, true, options);
			if (options.flatten) candidates.push.apply(candidates, nestedCandidates);
			else candidates.push({
				scopeParent: element,
				candidates: nestedCandidates
			});
		} else {
			if (matches.call(element, candidateSelector) && options.filter(element) && (includeContainer || !elements.includes(element))) candidates.push(element);
			var shadowRoot = element.shadowRoot || typeof options.getShadowRoot === "function" && options.getShadowRoot(element);
			var validShadowRoot = !_isInert(shadowRoot, false) && (!options.shadowRootFilter || options.shadowRootFilter(element));
			if (shadowRoot && validShadowRoot) {
				var _nestedCandidates = _getCandidatesIteratively(shadowRoot === true ? element.children : shadowRoot.children, true, options);
				if (options.flatten) candidates.push.apply(candidates, _nestedCandidates);
				else candidates.push({
					scopeParent: element,
					candidates: _nestedCandidates
				});
			} else elementsToCheck.unshift.apply(elementsToCheck, element.children);
		}
	}
	return candidates;
};
/**
* @private
* Determines if the node has an explicitly specified `tabindex` attribute.
* @param {HTMLElement} node
* @returns {boolean} True if so; false if not.
*/
var hasTabIndex = function hasTabIndex(node) {
	return !isNaN(parseInt(node.getAttribute("tabindex"), 10));
};
/**
* Determine the tab index of a given node.
* @param {HTMLElement} node
* @returns {number} Tab order (negative, 0, or positive number).
* @throws {Error} If `node` is falsy.
*/
var getTabIndex = function getTabIndex(node) {
	if (!node) throw new Error("No node provided");
	if (node.tabIndex < 0) {
		if ((/^(AUDIO|VIDEO|DETAILS)$/.test(node.tagName) || isContentEditable(node)) && !hasTabIndex(node)) return 0;
	}
	return node.tabIndex;
};
/**
* Determine the tab index of a given node __for sort order purposes__.
* @param {HTMLElement} node
* @param {boolean} [isScope] True for a custom element with shadow root or slot that, by default,
*  has tabIndex -1, but needs to be sorted by document order in order for its content to be
*  inserted into the correct sort position.
* @returns {number} Tab order (negative, 0, or positive number).
*/
var getSortOrderTabIndex = function getSortOrderTabIndex(node, isScope) {
	var tabIndex = getTabIndex(node);
	if (tabIndex < 0 && isScope && !hasTabIndex(node)) return 0;
	return tabIndex;
};
var sortOrderedTabbables = function sortOrderedTabbables(a, b) {
	return a.tabIndex === b.tabIndex ? a.documentOrder - b.documentOrder : a.tabIndex - b.tabIndex;
};
var isInput = function isInput(node) {
	return node.tagName === "INPUT";
};
var isHiddenInput = function isHiddenInput(node) {
	return isInput(node) && node.type === "hidden";
};
var isDetailsWithSummary = function isDetailsWithSummary(node) {
	return node.tagName === "DETAILS" && Array.prototype.slice.apply(node.children).some(function(child) {
		return child.tagName === "SUMMARY";
	});
};
var getCheckedRadio = function getCheckedRadio(nodes, form) {
	for (var i = 0; i < nodes.length; i++) if (nodes[i].checked && nodes[i].form === form) return nodes[i];
};
var isTabbableRadio = function isTabbableRadio(node) {
	if (!node.name) return true;
	var radioScope = node.form || getRootNode(node);
	var queryRadios = function queryRadios(name) {
		return radioScope.querySelectorAll("input[type=\"radio\"][name=\"" + name + "\"]");
	};
	var radioSet;
	if (typeof window !== "undefined" && typeof window.CSS !== "undefined" && typeof window.CSS.escape === "function") radioSet = queryRadios(window.CSS.escape(node.name));
	else try {
		radioSet = queryRadios(node.name);
	} catch (err) {
		console.error("Looks like you have a radio button with a name attribute containing invalid CSS selector characters and need the CSS.escape polyfill: %s", err.message);
		return false;
	}
	var checked = getCheckedRadio(radioSet, node.form);
	return !checked || checked === node;
};
var isRadio = function isRadio(node) {
	return isInput(node) && node.type === "radio";
};
var isNonTabbableRadio = function isNonTabbableRadio(node) {
	return isRadio(node) && !isTabbableRadio(node);
};
var isNodeAttached = function isNodeAttached(node) {
	var _nodeRoot;
	var nodeRoot = node && getRootNode(node);
	var nodeRootHost = (_nodeRoot = nodeRoot) === null || _nodeRoot === void 0 ? void 0 : _nodeRoot.host;
	var attached = false;
	if (nodeRoot && nodeRoot !== node) {
		var _nodeRootHost, _nodeRootHost$ownerDo, _node$ownerDocument;
		attached = !!((_nodeRootHost = nodeRootHost) !== null && _nodeRootHost !== void 0 && (_nodeRootHost$ownerDo = _nodeRootHost.ownerDocument) !== null && _nodeRootHost$ownerDo !== void 0 && _nodeRootHost$ownerDo.contains(nodeRootHost) || node !== null && node !== void 0 && (_node$ownerDocument = node.ownerDocument) !== null && _node$ownerDocument !== void 0 && _node$ownerDocument.contains(node));
		while (!attached && nodeRootHost) {
			var _nodeRoot2, _nodeRootHost2, _nodeRootHost2$ownerD;
			nodeRoot = getRootNode(nodeRootHost);
			nodeRootHost = (_nodeRoot2 = nodeRoot) === null || _nodeRoot2 === void 0 ? void 0 : _nodeRoot2.host;
			attached = !!((_nodeRootHost2 = nodeRootHost) !== null && _nodeRootHost2 !== void 0 && (_nodeRootHost2$ownerD = _nodeRootHost2.ownerDocument) !== null && _nodeRootHost2$ownerD !== void 0 && _nodeRootHost2$ownerD.contains(nodeRootHost));
		}
	}
	return attached;
};
var isZeroArea = function isZeroArea(node) {
	var _node$getBoundingClie = node.getBoundingClientRect(), width = _node$getBoundingClie.width, height = _node$getBoundingClie.height;
	return width === 0 && height === 0;
};
var isHidden = function isHidden(node, _ref) {
	var displayCheck = _ref.displayCheck, getShadowRoot = _ref.getShadowRoot;
	if (displayCheck === "full-native") {
		if ("checkVisibility" in node) return !node.checkVisibility({
			checkOpacity: false,
			opacityProperty: false,
			contentVisibilityAuto: true,
			visibilityProperty: true,
			checkVisibilityCSS: true
		});
	}
	if (getComputedStyle(node).visibility === "hidden") return true;
	var nodeUnderDetails = matches.call(node, "details>summary:first-of-type") ? node.parentElement : node;
	if (matches.call(nodeUnderDetails, "details:not([open]) *")) return true;
	if (!displayCheck || displayCheck === "full" || displayCheck === "full-native" || displayCheck === "legacy-full") {
		if (typeof getShadowRoot === "function") {
			var originalNode = node;
			while (node) {
				var parentElement = node.parentElement;
				var rootNode = getRootNode(node);
				if (parentElement && !parentElement.shadowRoot && getShadowRoot(parentElement) === true) return isZeroArea(node);
				else if (node.assignedSlot) node = node.assignedSlot;
				else if (!parentElement && rootNode !== node.ownerDocument) node = rootNode.host;
				else node = parentElement;
			}
			node = originalNode;
		}
		if (isNodeAttached(node)) return !node.getClientRects().length;
		if (displayCheck !== "legacy-full") return true;
	} else if (displayCheck === "non-zero-area") return isZeroArea(node);
	return false;
};
var isDisabledFromFieldset = function isDisabledFromFieldset(node) {
	if (/^(INPUT|BUTTON|SELECT|TEXTAREA)$/.test(node.tagName)) {
		var parentNode = node.parentElement;
		while (parentNode) {
			if (parentNode.tagName === "FIELDSET" && parentNode.disabled) {
				for (var i = 0; i < parentNode.children.length; i++) {
					var child = parentNode.children.item(i);
					if (child.tagName === "LEGEND") return matches.call(parentNode, "fieldset[disabled] *") ? true : !child.contains(node);
				}
				return true;
			}
			parentNode = parentNode.parentElement;
		}
	}
	return false;
};
var isNodeMatchingSelectorFocusable = function isNodeMatchingSelectorFocusable(options, node) {
	if (node.disabled || isHiddenInput(node) || isHidden(node, options) || isDetailsWithSummary(node) || isDisabledFromFieldset(node)) return false;
	return true;
};
var isNodeMatchingSelectorTabbable = function isNodeMatchingSelectorTabbable(options, node) {
	if (isNonTabbableRadio(node) || getTabIndex(node) < 0 || !isNodeMatchingSelectorFocusable(options, node)) return false;
	return true;
};
var isShadowRootTabbable = function isShadowRootTabbable(shadowHostNode) {
	var tabIndex = parseInt(shadowHostNode.getAttribute("tabindex"), 10);
	if (isNaN(tabIndex) || tabIndex >= 0) return true;
	return false;
};
/**
* @param {Array.<Element|CandidateScope>} candidates
* @returns Element[]
*/
var _sortByOrder = function sortByOrder(candidates) {
	var regularTabbables = [];
	var orderedTabbables = [];
	candidates.forEach(function(item, i) {
		var isScope = !!item.scopeParent;
		var element = isScope ? item.scopeParent : item;
		var candidateTabindex = getSortOrderTabIndex(element, isScope);
		var elements = isScope ? _sortByOrder(item.candidates) : element;
		if (candidateTabindex === 0) isScope ? regularTabbables.push.apply(regularTabbables, elements) : regularTabbables.push(element);
		else orderedTabbables.push({
			documentOrder: i,
			tabIndex: candidateTabindex,
			item,
			isScope,
			content: elements
		});
	});
	return orderedTabbables.sort(sortOrderedTabbables).reduce(function(acc, sortable) {
		sortable.isScope ? acc.push.apply(acc, sortable.content) : acc.push(sortable.content);
		return acc;
	}, []).concat(regularTabbables);
};
var tabbable = function tabbable(container, options) {
	options = options || {};
	var candidates;
	if (options.getShadowRoot) candidates = _getCandidatesIteratively([container], options.includeContainer, {
		filter: isNodeMatchingSelectorTabbable.bind(null, options),
		flatten: false,
		getShadowRoot: options.getShadowRoot,
		shadowRootFilter: isShadowRootTabbable
	});
	else candidates = getCandidates(container, options.includeContainer, isNodeMatchingSelectorTabbable.bind(null, options));
	return _sortByOrder(candidates);
};
var focusable = function focusable(container, options) {
	options = options || {};
	var candidates;
	if (options.getShadowRoot) candidates = _getCandidatesIteratively([container], options.includeContainer, {
		filter: isNodeMatchingSelectorFocusable.bind(null, options),
		flatten: true,
		getShadowRoot: options.getShadowRoot
	});
	else candidates = getCandidates(container, options.includeContainer, isNodeMatchingSelectorFocusable.bind(null, options));
	return candidates;
};
var focusableCandidateSelector = /* @__PURE__ */ candidateSelectors.concat("iframe:not([inert]):not([inert] *)").join(",");
var isFocusable = function isFocusable(node, options) {
	options = options || {};
	if (!node) throw new Error("No node provided");
	if (matches.call(node, focusableCandidateSelector) === false) return false;
	return isNodeMatchingSelectorFocusable(options, node);
};
//#endregion
//#region node_modules/bits-ui/dist/internal/arrays.js
/**
* Checks if the given index is valid for the given array.
*
* @param index - The index to check
* @param arr - The array to check
*/
function isValidIndex(index, arr) {
	return index >= 0 && index < arr.length;
}
/**
* Returns the array element after the given index, or undefined for out-of-bounds or empty arrays.
* @param array the array.
* @param index the index of the current element.
* @param loop loop to the beginning of the array if the next index is out of bounds?
*/
/**
* Returns the array element after the given index, or undefined for out-of-bounds or empty arrays.
* For single-element arrays, returns the element if the index is 0.
* @param array the array.
* @param index the index of the current element.
* @param loop loop to the beginning of the array if the next index is out of bounds?
*/
function next(array, index, loop = true) {
	if (array.length === 0 || index < 0 || index >= array.length) return;
	if (array.length === 1 && index === 0) return array[0];
	if (index === array.length - 1) return loop ? array[0] : void 0;
	return array[index + 1];
}
/**
* Returns the array element prior to the given index, or undefined for out-of-bounds or empty arrays.
* For single-element arrays, returns the element if the index is 0.
* @param array the array.
* @param index the index of the current element.
* @param loop loop to the end of the array if the previous index is out of bounds?
*/
function prev(array, index, loop = true) {
	if (array.length === 0 || index < 0 || index >= array.length) return;
	if (array.length === 1 && index === 0) return array[0];
	if (index === 0) return loop ? array[array.length - 1] : void 0;
	return array[index - 1];
}
/**
* Returns the element some number after the given index. If the target index is out of bounds:
*   - If looping is disabled, the first or last element will be returned.
*   - If looping is enabled, it will wrap around the array.
* Returns undefined for empty arrays or out-of-bounds initial indices.
* @param array the array.
* @param index the index of the current element.
* @param increment the number of elements to move forward (can be negative).
* @param loop loop around the array if the target index is out of bounds?
*/
function forward(array, index, increment, loop = true) {
	if (array.length === 0 || index < 0 || index >= array.length) return;
	let targetIndex = index + increment;
	if (loop) targetIndex = (targetIndex % array.length + array.length) % array.length;
	else targetIndex = Math.max(0, Math.min(targetIndex, array.length - 1));
	return array[targetIndex];
}
/**
* Returns the element some number before the given index. If the target index is out of bounds:
*   - If looping is disabled, the first or last element will be returned.
*   - If looping is enabled, it will wrap around the array.
* Returns undefined for empty arrays or out-of-bounds initial indices.
* @param array the array.
* @param index the index of the current element.
* @param decrement the number of elements to move backward (can be negative).
* @param loop loop around the array if the target index is out of bounds?
*/
function backward(array, index, decrement, loop = true) {
	if (array.length === 0 || index < 0 || index >= array.length) return;
	let targetIndex = index - decrement;
	if (loop) targetIndex = (targetIndex % array.length + array.length) % array.length;
	else targetIndex = Math.max(0, Math.min(targetIndex, array.length - 1));
	return array[targetIndex];
}
/**
* Finds the next matching item from a list of values based on a search string.
*
* This function handles several special cases in typeahead behavior:
*
* 1. Space handling: When a search string ends with a space, it handles it specially:
*    - If there's only one match for the text before the space, it ignores the space
*    - If there are multiple matches and the current match already starts with the search prefix
*      followed by a space, it keeps the current match (doesn't change selection on space)
*    - Only after typing characters beyond the space will it move to a more specific match
*
* 2. Repeated character handling: If a search consists of repeated characters (e.g., "aaa"),
*    it treats it as a single character for matching purposes
*
* 3. Cycling behavior: The function wraps around the values array starting from the current match
*    to find the next appropriate match, creating a cycling selection behavior
*
* @param values - Array of string values to search through (e.g., the text content of menu items)
* @param search - The current search string typed by the user
* @param currentMatch - The currently selected/matched item, if any
* @returns The next matching value that should be selected, or undefined if no match is found
*/
function getNextMatch(values, search, currentMatch) {
	const lowerSearch = search.toLowerCase();
	if (lowerSearch.endsWith(" ")) {
		const searchWithoutSpace = lowerSearch.slice(0, -1);
		/**
		* If there's only one match for the prefix without space, we don't
		* watch to match with space.
		*/
		if (values.filter((value) => value.toLowerCase().startsWith(searchWithoutSpace)).length <= 1) return getNextMatch(values, searchWithoutSpace, currentMatch);
		const currentMatchLowercase = currentMatch?.toLowerCase();
		/**
		* If the current match already starts with the search prefix and has a space afterward,
		* and the user has only typed up to that space, keep the current match until they
		* disambiguate.
		*/
		if (currentMatchLowercase && currentMatchLowercase.startsWith(searchWithoutSpace) && currentMatchLowercase.charAt(searchWithoutSpace.length) === " " && search.trim() === searchWithoutSpace) return currentMatch;
		/**
		* With multiple matches, find items that match the full search string with space
		*/
		const spacedMatches = values.filter((value) => value.toLowerCase().startsWith(lowerSearch));
		/**
		* If we found matches with the space, use the first one that's not the current match
		*/
		if (spacedMatches.length > 0) {
			const currentMatchIndex = currentMatch ? values.indexOf(currentMatch) : -1;
			return wrapArray(spacedMatches, Math.max(currentMatchIndex, 0)).find((match) => match !== currentMatch) || currentMatch;
		}
	}
	const normalizedSearch = search.length > 1 && Array.from(search).every((char) => char === search[0]) ? search[0] : search;
	const normalizedLowerSearch = normalizedSearch.toLowerCase();
	const currentMatchIndex = currentMatch ? values.indexOf(currentMatch) : -1;
	let wrappedValues = wrapArray(values, Math.max(currentMatchIndex, 0));
	if (normalizedSearch.length === 1) wrappedValues = wrappedValues.filter((v) => v !== currentMatch);
	const nextMatch = wrappedValues.find((value) => value?.toLowerCase().startsWith(normalizedLowerSearch));
	return nextMatch !== currentMatch ? nextMatch : void 0;
}
/**
* Wraps an array around itself at a given start index
* Example: `wrapArray(['a', 'b', 'c', 'd'], 2) === ['c', 'd', 'a', 'b']`
*/
function wrapArray(array, startIndex) {
	return array.map((_, index) => array[(startIndex + index) % array.length]);
}
//#endregion
//#region node_modules/bits-ui/dist/internal/box-auto-reset.svelte.js
var defaultOptions = {
	afterMs: 1e4,
	onChange: noop
};
function boxAutoReset(defaultValue, options) {
	const { afterMs, onChange, getWindow } = {
		...defaultOptions,
		...options
	};
	let timeout = null;
	let value = state$1(proxy(defaultValue));
	function resetAfter() {
		return getWindow().setTimeout(() => {
			set(value, defaultValue, true);
			onChange?.(defaultValue);
		}, afterMs);
	}
	user_effect(() => {
		return () => {
			if (timeout) getWindow().clearTimeout(timeout);
		};
	});
	return boxWith(() => get$2(value), (v) => {
		set(value, v, true);
		onChange?.(v);
		if (timeout) getWindow().clearTimeout(timeout);
		timeout = resetAfter();
	});
}
//#endregion
//#region node_modules/bits-ui/dist/internal/dom-typeahead.svelte.js
var DOMTypeahead = class {
	#opts;
	#search;
	#onMatch = user_derived(() => {
		if (this.#opts.onMatch) return this.#opts.onMatch;
		return (node) => node.focus();
	});
	#getCurrentItem = user_derived(() => {
		if (this.#opts.getCurrentItem) return this.#opts.getCurrentItem;
		return this.#opts.getActiveElement;
	});
	constructor(opts) {
		this.#opts = opts;
		this.#search = boxAutoReset("", {
			afterMs: 1e3,
			getWindow: opts.getWindow
		});
		this.handleTypeaheadSearch = this.handleTypeaheadSearch.bind(this);
		this.resetTypeahead = this.resetTypeahead.bind(this);
	}
	handleTypeaheadSearch(key, candidates) {
		if (!candidates.length) return;
		this.#search.current = this.#search.current + key;
		const currentItem = get$2(this.#getCurrentItem)();
		const currentMatch = candidates.find((item) => item === currentItem)?.textContent?.trim() ?? "";
		const nextMatch = getNextMatch(candidates.map((item) => item.textContent?.trim() ?? ""), this.#search.current, currentMatch);
		const newItem = candidates.find((item) => item.textContent?.trim() === nextMatch);
		if (newItem) get$2(this.#onMatch)(newItem);
		return newItem;
	}
	resetTypeahead() {
		this.#search.current = "";
	}
	get search() {
		return this.#search.current;
	}
};
//#endregion
//#region node_modules/bits-ui/dist/bits/menu/menu.svelte.js
var CONTEXT_MENU_TRIGGER_ATTR = "data-context-menu-trigger";
var CONTEXT_MENU_CONTENT_ATTR = "data-context-menu-content";
new Context$1("Menu.Root");
new Context$1("Menu.Root | Menu.Sub");
new Context$1("Menu.Content");
new Context$1("Menu.Group | Menu.RadioGroup");
new Context$1("Menu.RadioGroup");
new Context$1("Menu.CheckboxGroup");
new CustomEventDispatcher("bitsmenuopen", {
	bubbles: false,
	cancelable: true
});
createBitsAttrs({
	component: "menu",
	parts: [
		"trigger",
		"content",
		"sub-trigger",
		"item",
		"group",
		"group-heading",
		"checkbox-group",
		"checkbox-item",
		"radio-group",
		"radio-item",
		"separator",
		"sub-content",
		"arrow"
	]
});
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/dismissible-layer/use-dismissable-layer.svelte.js
globalThis.bitsDismissableLayers ??= /* @__PURE__ */ new Map();
var DismissibleLayerState = class DismissibleLayerState {
	static create(opts) {
		return new DismissibleLayerState(opts);
	}
	opts;
	#interactOutsideProp;
	#behaviorType;
	#interceptedEvents = { pointerdown: false };
	#isResponsibleLayer = false;
	#isFocusInsideDOMTree = false;
	#documentObj = void 0;
	#onFocusOutside;
	#unsubClickListener = noop;
	constructor(opts) {
		this.opts = opts;
		this.#behaviorType = opts.interactOutsideBehavior;
		this.#interactOutsideProp = opts.onInteractOutside;
		this.#onFocusOutside = opts.onFocusOutside;
		user_effect(() => {
			this.#documentObj = getOwnerDocument(this.opts.ref.current);
		});
		let unsubEvents = noop;
		const cleanup = () => {
			this.#resetState();
			globalThis.bitsDismissableLayers.delete(this);
			this.#handleInteractOutside.destroy();
			unsubEvents();
		};
		watch$1([() => this.opts.enabled.current, () => this.opts.ref.current], () => {
			if (!this.opts.enabled.current || !this.opts.ref.current) return;
			afterSleep(1, () => {
				if (!this.opts.ref.current) return;
				globalThis.bitsDismissableLayers.set(this, this.#behaviorType);
				unsubEvents();
				unsubEvents = this.#addEventListeners();
			});
			return cleanup;
		});
		onDestroyEffect(() => {
			this.#resetState.destroy();
			globalThis.bitsDismissableLayers.delete(this);
			this.#handleInteractOutside.destroy();
			this.#unsubClickListener();
			unsubEvents();
		});
	}
	#handleFocus = (event) => {
		if (event.defaultPrevented) return;
		if (!this.opts.ref.current) return;
		afterTick(() => {
			if (!this.opts.ref.current || this.#isTargetWithinLayer(event.target)) return;
			if (event.target && !this.#isFocusInsideDOMTree) this.#onFocusOutside.current?.(event);
		});
	};
	#addEventListeners() {
		return executeCallbacks(
			/**
			* CAPTURE INTERACTION START
			* mark interaction-start event as intercepted.
			* mark responsible layer during interaction start
			* to avoid checking if is responsible layer during interaction end
			* when a new floating element may have been opened.
			*/
			on(this.#documentObj, "pointerdown", executeCallbacks(this.#markInterceptedEvent, this.#markResponsibleLayer), { capture: true }),
			/**
			* BUBBLE INTERACTION START
			* Mark interaction-start event as non-intercepted. Debounce `onInteractOutsideStart`
			* to avoid prematurely checking if other events were intercepted.
			*/
			on(this.#documentObj, "pointerdown", executeCallbacks(this.#markNonInterceptedEvent, this.#handleInteractOutside)),
			/**
			* HANDLE FOCUS OUTSIDE
			*/
			on(this.#documentObj, "focusin", this.#handleFocus)
		);
	}
	#handleDismiss = (e) => {
		let event = e;
		if (event.defaultPrevented) event = createWrappedEvent(e);
		this.#interactOutsideProp.current(e);
	};
	#handleInteractOutside = debounce$1((e) => {
		if (!this.opts.ref.current) {
			this.#unsubClickListener();
			return;
		}
		const isEventValid = this.opts.isValidEvent.current(e, this.opts.ref.current) || isValidEvent(e, this.opts.ref.current);
		if (!this.#isResponsibleLayer || this.#isAnyEventIntercepted() || !isEventValid) {
			this.#unsubClickListener();
			return;
		}
		let event = e;
		if (event.defaultPrevented) event = createWrappedEvent(event);
		if (this.#behaviorType.current !== "close" && this.#behaviorType.current !== "defer-otherwise-close") {
			this.#unsubClickListener();
			return;
		}
		if (e.pointerType === "touch") {
			this.#unsubClickListener();
			this.#unsubClickListener = on(this.#documentObj, "click", this.#handleDismiss, { once: true });
		} else this.#interactOutsideProp.current(event);
	}, 10);
	#markInterceptedEvent = (e) => {
		this.#interceptedEvents[e.type] = true;
	};
	#markNonInterceptedEvent = (e) => {
		this.#interceptedEvents[e.type] = false;
	};
	#markResponsibleLayer = () => {
		if (!this.opts.ref.current) return;
		this.#isResponsibleLayer = isResponsibleLayer(this.opts.ref.current);
	};
	#isTargetWithinLayer = (target) => {
		if (!this.opts.ref.current) return false;
		return isOrContainsTarget(this.opts.ref.current, target);
	};
	#resetState = debounce$1(() => {
		for (const eventType in this.#interceptedEvents) this.#interceptedEvents[eventType] = false;
		this.#isResponsibleLayer = false;
	}, 20);
	#isAnyEventIntercepted() {
		return Object.values(this.#interceptedEvents).some(Boolean);
	}
	#onfocuscapture = () => {
		this.#isFocusInsideDOMTree = true;
	};
	#onblurcapture = () => {
		this.#isFocusInsideDOMTree = false;
	};
	props = {
		onfocuscapture: this.#onfocuscapture,
		onblurcapture: this.#onblurcapture
	};
};
function getTopMostDismissableLayer(layersArr = [...globalThis.bitsDismissableLayers]) {
	return layersArr.findLast(([_, { current: behaviorType }]) => behaviorType === "close" || behaviorType === "ignore");
}
function isResponsibleLayer(node) {
	const layersArr = [...globalThis.bitsDismissableLayers];
	/**
	* We first check if we can find a top layer with `close` or `ignore`.
	* If that top layer was found and matches the provided node, then the node is
	* responsible for the outside interaction. Otherwise, we know that all layers defer so
	* the first layer is the responsible one.
	*/
	const topMostLayer = getTopMostDismissableLayer(layersArr);
	if (topMostLayer) return topMostLayer[0].opts.ref.current === node;
	const [firstLayerNode] = layersArr[0];
	return firstLayerNode.opts.ref.current === node;
}
function isValidEvent(e, node) {
	const target = e.target;
	if (!isElementOrSVGElement(target)) return false;
	const targetIsContextMenuTrigger = Boolean(target.closest(`[${CONTEXT_MENU_TRIGGER_ATTR}]`));
	const nodeIsContextMenu = Boolean(node.closest(`[${CONTEXT_MENU_CONTENT_ATTR}]`));
	if ("button" in e && e.button > 0 && !targetIsContextMenuTrigger) return false;
	if ("button" in e && e.button === 0 && targetIsContextMenuTrigger && nodeIsContextMenu) return true;
	if (targetIsContextMenuTrigger && nodeIsContextMenu) return false;
	return getOwnerDocument(target).documentElement.contains(target) && !isOrContainsTarget(node, target) && isClickTrulyOutside(e, node);
}
function createWrappedEvent(e) {
	const capturedCurrentTarget = e.currentTarget;
	const capturedTarget = e.target;
	let newEvent;
	if (e instanceof PointerEvent) newEvent = new PointerEvent(e.type, e);
	else newEvent = new PointerEvent("pointerdown", e);
	let isPrevented = false;
	return new Proxy(newEvent, { get: (target, prop) => {
		if (prop === "currentTarget") return capturedCurrentTarget;
		if (prop === "target") return capturedTarget;
		if (prop === "preventDefault") return () => {
			isPrevented = true;
			if (typeof target.preventDefault === "function") target.preventDefault();
		};
		if (prop === "defaultPrevented") return isPrevented;
		if (prop in target) return target[prop];
		return e[prop];
	} });
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/dismissible-layer/dismissible-layer.svelte
function Dismissible_layer($$anchor, $$props) {
	push($$props, true);
	let interactOutsideBehavior = prop($$props, "interactOutsideBehavior", 3, "close"), onInteractOutside = prop($$props, "onInteractOutside", 3, noop), onFocusOutside = prop($$props, "onFocusOutside", 3, noop), isValidEvent = prop($$props, "isValidEvent", 3, () => false);
	const dismissibleLayerState = DismissibleLayerState.create({
		id: boxWith(() => $$props.id),
		interactOutsideBehavior: boxWith(() => interactOutsideBehavior()),
		onInteractOutside: boxWith(() => onInteractOutside()),
		enabled: boxWith(() => $$props.enabled),
		onFocusOutside: boxWith(() => onFocusOutside()),
		isValidEvent: boxWith(() => isValidEvent()),
		ref: $$props.ref
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.children ?? noop$1, () => ({ props: dismissibleLayerState.props }));
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/escape-layer/use-escape-layer.svelte.js
globalThis.bitsEscapeLayers ??= /* @__PURE__ */ new Map();
var EscapeLayerState = class EscapeLayerState {
	static create(opts) {
		return new EscapeLayerState(opts);
	}
	opts;
	domContext;
	constructor(opts) {
		this.opts = opts;
		this.domContext = new DOMContext(this.opts.ref);
		let unsubEvents = noop;
		watch$1(() => opts.enabled.current, (enabled) => {
			if (enabled) {
				globalThis.bitsEscapeLayers.set(this, opts.escapeKeydownBehavior);
				unsubEvents = this.#addEventListener();
			}
			return () => {
				unsubEvents();
				globalThis.bitsEscapeLayers.delete(this);
			};
		});
	}
	#addEventListener = () => {
		return on(this.domContext.getDocument(), "keydown", this.#onkeydown, { passive: false });
	};
	#onkeydown = (e) => {
		if (e.key !== "Escape" || !isResponsibleEscapeLayer(this)) return;
		const clonedEvent = new KeyboardEvent(e.type, e);
		e.preventDefault();
		const behaviorType = this.opts.escapeKeydownBehavior.current;
		if (behaviorType !== "close" && behaviorType !== "defer-otherwise-close") return;
		this.opts.onEscapeKeydown.current(clonedEvent);
	};
};
function isResponsibleEscapeLayer(instance) {
	const layersArr = [...globalThis.bitsEscapeLayers];
	/**
	* We first check if we can find a top layer with `close` or `ignore`.
	* If that top layer was found and matches the provided node, then the node is
	* responsible for the escape. Otherwise, we know that all layers defer so
	* the first layer is the responsible one.
	*/
	const topMostLayer = layersArr.findLast(([_, { current: behaviorType }]) => behaviorType === "close" || behaviorType === "ignore");
	if (topMostLayer) return topMostLayer[0] === instance;
	const [firstLayerNode] = layersArr[0];
	return firstLayerNode === instance;
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/escape-layer/escape-layer.svelte
function Escape_layer($$anchor, $$props) {
	push($$props, true);
	let escapeKeydownBehavior = prop($$props, "escapeKeydownBehavior", 3, "close"), onEscapeKeydown = prop($$props, "onEscapeKeydown", 3, noop);
	EscapeLayerState.create({
		escapeKeydownBehavior: boxWith(() => escapeKeydownBehavior()),
		onEscapeKeydown: boxWith(() => onEscapeKeydown()),
		enabled: boxWith(() => $$props.enabled),
		ref: $$props.ref
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.children ?? noop$1);
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/focus-scope/focus-scope-manager.js
var FocusScopeManager = class FocusScopeManager {
	static instance;
	#scopeStack = simpleBox([]);
	#focusHistory = /* @__PURE__ */ new WeakMap();
	#preFocusHistory = /* @__PURE__ */ new WeakMap();
	static getInstance() {
		if (!this.instance) this.instance = new FocusScopeManager();
		return this.instance;
	}
	register(scope) {
		const current = this.getActive();
		if (current && current !== scope) current.pause();
		const activeElement = document.activeElement;
		if (activeElement && activeElement !== document.body) this.#preFocusHistory.set(scope, activeElement);
		this.#scopeStack.current = this.#scopeStack.current.filter((s) => s !== scope);
		this.#scopeStack.current.unshift(scope);
	}
	unregister(scope) {
		this.#scopeStack.current = this.#scopeStack.current.filter((s) => s !== scope);
		const next = this.getActive();
		if (next) next.resume();
	}
	getActive() {
		return this.#scopeStack.current[0];
	}
	setFocusMemory(scope, element) {
		this.#focusHistory.set(scope, element);
	}
	getFocusMemory(scope) {
		return this.#focusHistory.get(scope);
	}
	isActiveScope(scope) {
		return this.getActive() === scope;
	}
	setPreFocusMemory(scope, element) {
		this.#preFocusHistory.set(scope, element);
	}
	getPreFocusMemory(scope) {
		return this.#preFocusHistory.get(scope);
	}
	clearPreFocusMemory(scope) {
		this.#preFocusHistory.delete(scope);
	}
};
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/focus-scope/focus-scope.svelte.js
var FocusScope = class FocusScope {
	#paused = false;
	#container = null;
	#manager = FocusScopeManager.getInstance();
	#cleanupFns = [];
	#opts;
	constructor(opts) {
		this.#opts = opts;
	}
	get paused() {
		return this.#paused;
	}
	pause() {
		this.#paused = true;
	}
	resume() {
		this.#paused = false;
	}
	#cleanup() {
		for (const fn of this.#cleanupFns) fn();
		this.#cleanupFns = [];
	}
	mount(container) {
		if (this.#container) this.unmount();
		this.#container = container;
		this.#manager.register(this);
		this.#setupEventListeners();
		this.#handleOpenAutoFocus();
	}
	unmount() {
		if (!this.#container) return;
		this.#cleanup();
		this.#handleCloseAutoFocus();
		this.#manager.unregister(this);
		this.#manager.clearPreFocusMemory(this);
		this.#container = null;
	}
	#handleOpenAutoFocus() {
		if (!this.#container) return;
		const event = new CustomEvent("focusScope.onOpenAutoFocus", {
			bubbles: false,
			cancelable: true
		});
		this.#opts.onOpenAutoFocus.current(event);
		if (!event.defaultPrevented) requestAnimationFrame(() => {
			if (!this.#container) return;
			const firstTabbable = this.#getFirstTabbable();
			if (firstTabbable) {
				firstTabbable.focus();
				this.#manager.setFocusMemory(this, firstTabbable);
			} else this.#container.focus();
		});
	}
	#handleCloseAutoFocus() {
		const event = new CustomEvent("focusScope.onCloseAutoFocus", {
			bubbles: false,
			cancelable: true
		});
		this.#opts.onCloseAutoFocus.current?.(event);
		if (!event.defaultPrevented) {
			const preFocusedElement = this.#manager.getPreFocusMemory(this);
			if (preFocusedElement && document.contains(preFocusedElement)) try {
				preFocusedElement.focus();
			} catch {
				document.body.focus();
			}
		}
	}
	#setupEventListeners() {
		if (!this.#container || !this.#opts.trap.current) return;
		const container = this.#container;
		const doc = container.ownerDocument;
		const handleFocus = (e) => {
			if (this.#paused || !this.#manager.isActiveScope(this)) return;
			const target = e.target;
			if (!target) return;
			if (container.contains(target)) this.#manager.setFocusMemory(this, target);
			else {
				const lastFocused = this.#manager.getFocusMemory(this);
				if (lastFocused && container.contains(lastFocused) && isFocusable(lastFocused)) {
					e.preventDefault();
					lastFocused.focus();
				} else {
					const firstTabbable = this.#getFirstTabbable();
					const firstFocusable = this.#getAllFocusables()[0];
					(firstTabbable || firstFocusable || container).focus();
				}
			}
		};
		const handleKeydown = (e) => {
			if (!this.#opts.loop || this.#paused || e.key !== "Tab") return;
			if (!this.#manager.isActiveScope(this)) return;
			const tabbables = this.#getTabbables();
			if (tabbables.length === 0) return;
			const first = tabbables[0];
			const last = tabbables[tabbables.length - 1];
			if (!e.shiftKey && doc.activeElement === last) {
				e.preventDefault();
				first.focus();
			} else if (e.shiftKey && doc.activeElement === first) {
				e.preventDefault();
				last.focus();
			}
		};
		this.#cleanupFns.push(on(doc, "focusin", handleFocus, { capture: true }), on(container, "keydown", handleKeydown));
		const observer = new MutationObserver(() => {
			const lastFocused = this.#manager.getFocusMemory(this);
			if (lastFocused && !container.contains(lastFocused)) {
				const firstTabbable = this.#getFirstTabbable();
				const firstFocusable = this.#getAllFocusables()[0];
				const elementToFocus = firstTabbable || firstFocusable;
				if (elementToFocus) {
					elementToFocus.focus();
					this.#manager.setFocusMemory(this, elementToFocus);
				} else container.focus();
			}
		});
		observer.observe(container, {
			childList: true,
			subtree: true
		});
		this.#cleanupFns.push(() => observer.disconnect());
	}
	#getTabbables() {
		if (!this.#container) return [];
		return tabbable(this.#container, {
			includeContainer: false,
			getShadowRoot: true
		});
	}
	#getFirstTabbable() {
		return this.#getTabbables()[0] || null;
	}
	#getAllFocusables() {
		if (!this.#container) return [];
		return focusable(this.#container, {
			includeContainer: false,
			getShadowRoot: true
		});
	}
	static use(opts) {
		let scope = null;
		watch$1([() => opts.ref.current, () => opts.enabled.current], ([ref, enabled]) => {
			if (ref && enabled) {
				if (!scope) scope = new FocusScope(opts);
				scope.mount(ref);
			} else if (scope) {
				scope.unmount();
				scope = null;
			}
		});
		onDestroyEffect(() => {
			scope?.unmount();
		});
		return { get props() {
			return { tabindex: -1 };
		} };
	}
};
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/focus-scope/focus-scope.svelte
function Focus_scope($$anchor, $$props) {
	push($$props, true);
	let enabled = prop($$props, "enabled", 3, false), trapFocus = prop($$props, "trapFocus", 3, false), loop = prop($$props, "loop", 3, false), onCloseAutoFocus = prop($$props, "onCloseAutoFocus", 3, noop), onOpenAutoFocus = prop($$props, "onOpenAutoFocus", 3, noop);
	const focusScopeState = FocusScope.use({
		enabled: boxWith(() => enabled()),
		trap: boxWith(() => trapFocus()),
		loop: loop(),
		onCloseAutoFocus: boxWith(() => onCloseAutoFocus()),
		onOpenAutoFocus: boxWith(() => onOpenAutoFocus()),
		ref: $$props.ref
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.focusScope ?? noop$1, () => ({ props: focusScopeState.props }));
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/text-selection-layer/use-text-selection-layer.svelte.js
var noopPointer = () => {};
globalThis.bitsTextSelectionLayers ??= /* @__PURE__ */ new Map();
var TextSelectionLayerState = class TextSelectionLayerState {
	static create(opts) {
		return new TextSelectionLayerState(opts);
	}
	opts;
	domContext;
	#unsubSelectionLock = noop;
	#enabledSnapshot = false;
	#onPointerDownSnapshot = noopPointer;
	#onPointerUpSnapshot = noopPointer;
	constructor(opts) {
		this.opts = opts;
		this.domContext = new DOMContext(opts.ref);
		let unsubEvents = noop;
		watch$1(() => [
			this.opts.enabled.current,
			this.opts.onPointerDown.current,
			this.opts.onPointerUp.current
		], ([enabled, onPointerDown, onPointerUp]) => {
			this.#enabledSnapshot = enabled;
			this.#onPointerDownSnapshot = onPointerDown;
			this.#onPointerUpSnapshot = onPointerUp;
			if (enabled) {
				globalThis.bitsTextSelectionLayers.set(this, this.opts.enabled);
				unsubEvents();
				unsubEvents = this.#addEventListeners();
			}
			return () => {
				this.#enabledSnapshot = false;
				unsubEvents();
				this.#resetSelectionLock();
				globalThis.bitsTextSelectionLayers.delete(this);
			};
		});
	}
	#addEventListeners() {
		return executeCallbacks(on(this.domContext.getDocument(), "pointerdown", this.#pointerdown), on(this.domContext.getDocument(), "pointerup", composeHandlers(this.#resetSelectionLock, this.#pointerupUserHandler)));
	}
	#pointerupUserHandler = (e) => {
		this.#onPointerUpSnapshot(e);
	};
	#pointerdown = (e) => {
		const node = this.opts.ref.current;
		const target = e.target;
		if (!isHTMLElement$1(node) || !isHTMLElement$1(target) || !this.#enabledSnapshot) return;
		/**
		* We only lock user-selection overflow if layer is the top most layer and
		* pointerdown occurred inside the node. You are still allowed to select text
		* outside the node provided pointerdown occurs outside the node.
		*/
		if (!isHighestLayer(this) || !contains(node, target)) return;
		this.#onPointerDownSnapshot(e);
		if (e.defaultPrevented) return;
		this.#unsubSelectionLock = preventTextSelectionOverflow(node, this.domContext.getDocument().body);
	};
	#resetSelectionLock = () => {
		this.#unsubSelectionLock();
		this.#unsubSelectionLock = noop;
	};
};
var getUserSelect = (node) => node.style.userSelect || node.style.webkitUserSelect;
function preventTextSelectionOverflow(node, body) {
	const originalBodyUserSelect = getUserSelect(body);
	const originalNodeUserSelect = getUserSelect(node);
	setUserSelect(body, "none");
	setUserSelect(node, "text");
	return () => {
		setUserSelect(body, originalBodyUserSelect);
		setUserSelect(node, originalNodeUserSelect);
	};
}
function setUserSelect(node, value) {
	node.style.userSelect = value;
	node.style.webkitUserSelect = value;
}
function isHighestLayer(instance) {
	const layersArr = [...globalThis.bitsTextSelectionLayers];
	if (!layersArr.length) return false;
	const highestLayer = layersArr.at(-1);
	if (!highestLayer) return false;
	return highestLayer[0] === instance;
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/text-selection-layer/text-selection-layer.svelte
function Text_selection_layer($$anchor, $$props) {
	push($$props, true);
	let preventOverflowTextSelection = prop($$props, "preventOverflowTextSelection", 3, true), onPointerDown = prop($$props, "onPointerDown", 3, noop), onPointerUp = prop($$props, "onPointerUp", 3, noop);
	TextSelectionLayerState.create({
		id: boxWith(() => $$props.id),
		onPointerDown: boxWith(() => onPointerDown()),
		onPointerUp: boxWith(() => onPointerUp()),
		enabled: boxWith(() => $$props.enabled && preventOverflowTextSelection()),
		ref: $$props.ref
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.children ?? noop$1);
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/internal/use-id.js
globalThis.bitsIdCounter ??= { current: 0 };
/**
* Generates a unique ID based on a global counter.
*/
function useId(prefix = "bits") {
	globalThis.bitsIdCounter.current++;
	return `${prefix}-${globalThis.bitsIdCounter.current}`;
}
//#endregion
//#region node_modules/bits-ui/dist/internal/shared-state.svelte.js
var SharedState = class {
	#factory;
	#subscribers = 0;
	#state = state$1();
	#scope;
	constructor(factory) {
		this.#factory = factory;
	}
	#dispose() {
		this.#subscribers -= 1;
		if (this.#scope && this.#subscribers <= 0) {
			this.#scope();
			set(this.#state, void 0);
			this.#scope = void 0;
		}
	}
	get(...args) {
		this.#subscribers += 1;
		if (get$2(this.#state) === void 0) this.#scope = effect_root(() => {
			set(this.#state, this.#factory(...args), true);
		});
		user_effect(() => {
			return () => {
				this.#dispose();
			};
		});
		return get$2(this.#state);
	}
};
//#endregion
//#region node_modules/bits-ui/dist/internal/body-scroll-lock.svelte.js
var lockMap = new SvelteMap();
var initialBodyStyle = state$1(null);
var stopTouchMoveListener = null;
var cleanupTimeoutId = null;
var isInCleanupTransition = false;
var anyLocked = boxWith(() => {
	for (const value of lockMap.values()) if (value) return true;
	return false;
});
/**
* We track the time we scheduled the cleanup to prevent race conditions
* when multiple locks are created/destroyed in the same tick, ensuring
* only the last one to schedule the cleanup will run.
*
* reference: https://github.com/huntabyte/bits-ui/issues/1639
*/
var cleanupScheduledAt = null;
var bodyLockStackCount = new SharedState(() => {
	function resetBodyStyle() {
		document.body.setAttribute("style", get$2(initialBodyStyle) ?? "");
		document.body.style.removeProperty("--scrollbar-width");
		isIOS && stopTouchMoveListener?.();
		set(initialBodyStyle, null);
	}
	function cancelPendingCleanup() {
		if (cleanupTimeoutId === null) return;
		window.clearTimeout(cleanupTimeoutId);
		cleanupTimeoutId = null;
	}
	function scheduleCleanupIfNoNewLocks(delay, callback) {
		cancelPendingCleanup();
		isInCleanupTransition = true;
		cleanupScheduledAt = Date.now();
		const currentCleanupId = cleanupScheduledAt;
		/**
		* We schedule the cleanup to run after a delay to allow new locks to register
		* that might have been added in the same tick as the current cleanup.
		*
		* If a new lock is added in the same tick, the cleanup will be cancelled and
		* a new cleanup will be scheduled.
		*
		* This is to prevent the cleanup from running too early and resetting the body
		* style before the new lock has had a chance to apply its styles.
		*/
		const cleanupFn = () => {
			cleanupTimeoutId = null;
			if (cleanupScheduledAt !== currentCleanupId) return;
			if (!isAnyLocked(lockMap)) {
				isInCleanupTransition = false;
				callback();
			} else isInCleanupTransition = false;
		};
		const actualDelay = delay === null ? 24 : delay;
		cleanupTimeoutId = window.setTimeout(cleanupFn, actualDelay);
	}
	function ensureInitialStyleCaptured() {
		if (get$2(initialBodyStyle) === null && lockMap.size === 0 && !isInCleanupTransition) set(initialBodyStyle, document.body.getAttribute("style"), true);
	}
	watch$1(() => anyLocked.current, () => {
		if (!anyLocked.current) return;
		ensureInitialStyleCaptured();
		isInCleanupTransition = false;
		const htmlStyle = getComputedStyle(document.documentElement);
		const bodyStyle = getComputedStyle(document.body);
		const hasStableGutter = htmlStyle.scrollbarGutter?.includes("stable") || bodyStyle.scrollbarGutter?.includes("stable");
		const verticalScrollbarWidth = window.innerWidth - document.documentElement.clientWidth;
		const config = {
			padding: Number.parseInt(bodyStyle.paddingRight ?? "0", 10) + verticalScrollbarWidth,
			margin: Number.parseInt(bodyStyle.marginRight ?? "0", 10)
		};
		if (verticalScrollbarWidth > 0 && !hasStableGutter) {
			document.body.style.paddingRight = `${config.padding}px`;
			document.body.style.marginRight = `${config.margin}px`;
			document.body.style.setProperty("--scrollbar-width", `${verticalScrollbarWidth}px`);
		}
		document.body.style.overflow = "hidden";
		if (isIOS) stopTouchMoveListener = on(document, "touchmove", (e) => {
			if (e.target !== document.documentElement) return;
			if (e.touches.length > 1) return;
			e.preventDefault();
		}, { passive: false });
		/**
		* We ensure pointer-events: none is applied _after_ DOM updates, so that any focus/
		* interaction changes from opening overlays/menus complete _before_ we block pointer
		* events.
		*
		* this avoids race conditions where pointer-events could be set too early and break
		* focus/interaction.
		*/
		afterTick(() => {
			document.body.style.pointerEvents = "none";
			document.body.style.overflow = "hidden";
		});
	});
	onDestroyEffect(() => {
		return () => {
			stopTouchMoveListener?.();
		};
	});
	return {
		get lockMap() {
			return lockMap;
		},
		resetBodyStyle,
		scheduleCleanupIfNoNewLocks,
		cancelPendingCleanup,
		ensureInitialStyleCaptured
	};
});
var BodyScrollLock = class {
	#id = useId();
	#initialState;
	#restoreScrollDelay = () => null;
	#countState;
	locked;
	constructor(initialState, restoreScrollDelay = () => null) {
		this.#initialState = initialState;
		this.#restoreScrollDelay = restoreScrollDelay;
		this.#countState = bodyLockStackCount.get();
		if (!this.#countState) return;
		/**
		* Since a new lock is being created, we cancel any pending cleanup to
		* prevent the cleanup from running too early and resetting the body style
		* before the new lock has had a chance to apply its styles.
		*
		* reference: https://github.com/huntabyte/bits-ui/issues/1639
		*/
		this.#countState.cancelPendingCleanup();
		this.#countState.ensureInitialStyleCaptured();
		this.#countState.lockMap.set(this.#id, this.#initialState ?? false);
		this.locked = boxWith(() => this.#countState.lockMap.get(this.#id) ?? false, (v) => this.#countState.lockMap.set(this.#id, v));
		onDestroyEffect(() => {
			this.#countState.lockMap.delete(this.#id);
			if (isAnyLocked(this.#countState.lockMap)) return;
			const restoreScrollDelay = this.#restoreScrollDelay();
			/**
			* We schedule the cleanup to run after a delay to handle same-tick
			* destroy/create scenarios.
			*
			* reference: https://github.com/huntabyte/bits-ui/issues/1639
			*/
			this.#countState.scheduleCleanupIfNoNewLocks(restoreScrollDelay, () => {
				this.#countState.resetBodyStyle();
			});
		});
	}
};
function isAnyLocked(map) {
	for (const [_, value] of map) if (value) return true;
	return false;
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/scroll-lock/scroll-lock.svelte
function Scroll_lock($$anchor, $$props) {
	push($$props, true);
	let preventScroll = prop($$props, "preventScroll", 3, true), restoreScrollDelay = prop($$props, "restoreScrollDelay", 3, null);
	if (preventScroll()) new BodyScrollLock(preventScroll(), () => restoreScrollDelay());
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/dialog/components/dialog-overlay.svelte
var root_3$8 = from_html(`<div><!></div>`);
function Dialog_overlay($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), forceMount = prop($$props, "forceMount", 3, false), ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"forceMount",
		"child",
		"children",
		"ref"
	]);
	const overlayState = DialogOverlayState.create({
		id: boxWith(() => id()),
		ref: boxWith(() => ref(), (v) => ref(v))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, overlayState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent_1 = ($$anchor) => {
		var fragment_1 = comment();
		var node_1 = first_child(fragment_1);
		var consequent = ($$anchor) => {
			var fragment_2 = comment();
			var node_2 = first_child(fragment_2);
			{
				let $0 = user_derived(() => ({
					props: mergeProps(get$2(mergedProps)),
					...overlayState.snippetProps
				}));
				snippet(node_2, () => $$props.child, () => get$2($0));
			}
			append($$anchor, fragment_2);
		};
		var alternate = ($$anchor) => {
			var div = root_3$8();
			attribute_effect(div, ($0) => ({ ...$0 }), [() => mergeProps(get$2(mergedProps))]);
			snippet(child(div), () => $$props.children ?? noop$1, () => overlayState.snippetProps);
			reset(div);
			append($$anchor, div);
		};
		if_block(node_1, ($$render) => {
			if ($$props.child) $$render(consequent);
			else $$render(alternate, -1);
		});
		append($$anchor, fragment_1);
	};
	if_block(node, ($$render) => {
		if (overlayState.shouldRender || forceMount()) $$render(consequent_1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/dialog/components/dialog-description.svelte
var root_2$15 = from_html(`<div><!></div>`);
function Dialog_description($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"children",
		"child",
		"ref"
	]);
	const descriptionState = DialogDescriptionState.create({
		id: boxWith(() => id()),
		ref: boxWith(() => ref(), (v) => ref(v))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, descriptionState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.child, () => ({ props: get$2(mergedProps) }));
		append($$anchor, fragment_1);
	};
	var alternate = ($$anchor) => {
		var div = root_2$15();
		attribute_effect(div, () => ({ ...get$2(mergedProps) }));
		snippet(child(div), () => $$props.children ?? noop$1);
		reset(div);
		append($$anchor, div);
	};
	if_block(node, ($$render) => {
		if ($$props.child) $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/@floating-ui/utils/dist/floating-ui.utils.mjs
/**
* Custom positioning reference element.
* @see https://floating-ui.com/docs/virtual-elements
*/
var sides = [
	"top",
	"right",
	"bottom",
	"left"
];
var min = Math.min;
var max = Math.max;
var round = Math.round;
var floor = Math.floor;
var createCoords = (v) => ({
	x: v,
	y: v
});
var oppositeSideMap = {
	left: "right",
	right: "left",
	bottom: "top",
	top: "bottom"
};
function clamp(start, value, end) {
	return max(start, min(value, end));
}
function evaluate(value, param) {
	return typeof value === "function" ? value(param) : value;
}
function getSide$1(placement) {
	return placement.split("-")[0];
}
function getAlignment(placement) {
	return placement.split("-")[1];
}
function getOppositeAxis(axis) {
	return axis === "x" ? "y" : "x";
}
function getAxisLength(axis) {
	return axis === "y" ? "height" : "width";
}
function getSideAxis(placement) {
	const firstChar = placement[0];
	return firstChar === "t" || firstChar === "b" ? "y" : "x";
}
function getAlignmentAxis(placement) {
	return getOppositeAxis(getSideAxis(placement));
}
function getAlignmentSides(placement, rects, rtl) {
	if (rtl === void 0) rtl = false;
	const alignment = getAlignment(placement);
	const alignmentAxis = getAlignmentAxis(placement);
	const length = getAxisLength(alignmentAxis);
	let mainAlignmentSide = alignmentAxis === "x" ? alignment === (rtl ? "end" : "start") ? "right" : "left" : alignment === "start" ? "bottom" : "top";
	if (rects.reference[length] > rects.floating[length]) mainAlignmentSide = getOppositePlacement(mainAlignmentSide);
	return [mainAlignmentSide, getOppositePlacement(mainAlignmentSide)];
}
function getExpandedPlacements(placement) {
	const oppositePlacement = getOppositePlacement(placement);
	return [
		getOppositeAlignmentPlacement(placement),
		oppositePlacement,
		getOppositeAlignmentPlacement(oppositePlacement)
	];
}
function getOppositeAlignmentPlacement(placement) {
	return placement.includes("start") ? placement.replace("start", "end") : placement.replace("end", "start");
}
var lrPlacement = ["left", "right"];
var rlPlacement = ["right", "left"];
var tbPlacement = ["top", "bottom"];
var btPlacement = ["bottom", "top"];
function getSideList(side, isStart, rtl) {
	switch (side) {
		case "top":
		case "bottom":
			if (rtl) return isStart ? rlPlacement : lrPlacement;
			return isStart ? lrPlacement : rlPlacement;
		case "left":
		case "right": return isStart ? tbPlacement : btPlacement;
		default: return [];
	}
}
function getOppositeAxisPlacements(placement, flipAlignment, direction, rtl) {
	const alignment = getAlignment(placement);
	let list = getSideList(getSide$1(placement), direction === "start", rtl);
	if (alignment) {
		list = list.map((side) => side + "-" + alignment);
		if (flipAlignment) list = list.concat(list.map(getOppositeAlignmentPlacement));
	}
	return list;
}
function getOppositePlacement(placement) {
	const side = getSide$1(placement);
	return oppositeSideMap[side] + placement.slice(side.length);
}
function expandPaddingObject(padding) {
	return {
		top: 0,
		right: 0,
		bottom: 0,
		left: 0,
		...padding
	};
}
function getPaddingObject(padding) {
	return typeof padding !== "number" ? expandPaddingObject(padding) : {
		top: padding,
		right: padding,
		bottom: padding,
		left: padding
	};
}
function rectToClientRect(rect) {
	const { x, y, width, height } = rect;
	return {
		width,
		height,
		top: y,
		left: x,
		right: x + width,
		bottom: y + height,
		x,
		y
	};
}
//#endregion
//#region node_modules/@floating-ui/core/dist/floating-ui.core.mjs
function computeCoordsFromPlacement(_ref, placement, rtl) {
	let { reference, floating } = _ref;
	const sideAxis = getSideAxis(placement);
	const alignmentAxis = getAlignmentAxis(placement);
	const alignLength = getAxisLength(alignmentAxis);
	const side = getSide$1(placement);
	const isVertical = sideAxis === "y";
	const commonX = reference.x + reference.width / 2 - floating.width / 2;
	const commonY = reference.y + reference.height / 2 - floating.height / 2;
	const commonAlign = reference[alignLength] / 2 - floating[alignLength] / 2;
	let coords;
	switch (side) {
		case "top":
			coords = {
				x: commonX,
				y: reference.y - floating.height
			};
			break;
		case "bottom":
			coords = {
				x: commonX,
				y: reference.y + reference.height
			};
			break;
		case "right":
			coords = {
				x: reference.x + reference.width,
				y: commonY
			};
			break;
		case "left":
			coords = {
				x: reference.x - floating.width,
				y: commonY
			};
			break;
		default: coords = {
			x: reference.x,
			y: reference.y
		};
	}
	switch (getAlignment(placement)) {
		case "start":
			coords[alignmentAxis] -= commonAlign * (rtl && isVertical ? -1 : 1);
			break;
		case "end":
			coords[alignmentAxis] += commonAlign * (rtl && isVertical ? -1 : 1);
			break;
	}
	return coords;
}
/**
* Resolves with an object of overflow side offsets that determine how much the
* element is overflowing a given clipping boundary on each side.
* - positive = overflowing the boundary by that number of pixels
* - negative = how many pixels left before it will overflow
* - 0 = lies flush with the boundary
* @see https://floating-ui.com/docs/detectOverflow
*/
async function detectOverflow(state, options) {
	var _await$platform$isEle;
	if (options === void 0) options = {};
	const { x, y, platform, rects, elements, strategy } = state;
	const { boundary = "clippingAncestors", rootBoundary = "viewport", elementContext = "floating", altBoundary = false, padding = 0 } = evaluate(options, state);
	const paddingObject = getPaddingObject(padding);
	const element = elements[altBoundary ? elementContext === "floating" ? "reference" : "floating" : elementContext];
	const clippingClientRect = rectToClientRect(await platform.getClippingRect({
		element: ((_await$platform$isEle = await (platform.isElement == null ? void 0 : platform.isElement(element))) != null ? _await$platform$isEle : true) ? element : element.contextElement || await (platform.getDocumentElement == null ? void 0 : platform.getDocumentElement(elements.floating)),
		boundary,
		rootBoundary,
		strategy
	}));
	const rect = elementContext === "floating" ? {
		x,
		y,
		width: rects.floating.width,
		height: rects.floating.height
	} : rects.reference;
	const offsetParent = await (platform.getOffsetParent == null ? void 0 : platform.getOffsetParent(elements.floating));
	const offsetScale = await (platform.isElement == null ? void 0 : platform.isElement(offsetParent)) ? await (platform.getScale == null ? void 0 : platform.getScale(offsetParent)) || {
		x: 1,
		y: 1
	} : {
		x: 1,
		y: 1
	};
	const elementClientRect = rectToClientRect(platform.convertOffsetParentRelativeRectToViewportRelativeRect ? await platform.convertOffsetParentRelativeRectToViewportRelativeRect({
		elements,
		rect,
		offsetParent,
		strategy
	}) : rect);
	return {
		top: (clippingClientRect.top - elementClientRect.top + paddingObject.top) / offsetScale.y,
		bottom: (elementClientRect.bottom - clippingClientRect.bottom + paddingObject.bottom) / offsetScale.y,
		left: (clippingClientRect.left - elementClientRect.left + paddingObject.left) / offsetScale.x,
		right: (elementClientRect.right - clippingClientRect.right + paddingObject.right) / offsetScale.x
	};
}
var MAX_RESET_COUNT = 50;
/**
* Computes the `x` and `y` coordinates that will place the floating element
* next to a given reference element.
*
* This export does not have any `platform` interface logic. You will need to
* write one for the platform you are using Floating UI with.
*/
var computePosition$1 = async (reference, floating, config) => {
	const { placement = "bottom", strategy = "absolute", middleware = [], platform } = config;
	const platformWithDetectOverflow = platform.detectOverflow ? platform : {
		...platform,
		detectOverflow
	};
	const rtl = await (platform.isRTL == null ? void 0 : platform.isRTL(floating));
	let rects = await platform.getElementRects({
		reference,
		floating,
		strategy
	});
	let { x, y } = computeCoordsFromPlacement(rects, placement, rtl);
	let statefulPlacement = placement;
	let resetCount = 0;
	const middlewareData = {};
	for (let i = 0; i < middleware.length; i++) {
		const currentMiddleware = middleware[i];
		if (!currentMiddleware) continue;
		const { name, fn } = currentMiddleware;
		const { x: nextX, y: nextY, data, reset } = await fn({
			x,
			y,
			initialPlacement: placement,
			placement: statefulPlacement,
			strategy,
			middlewareData,
			rects,
			platform: platformWithDetectOverflow,
			elements: {
				reference,
				floating
			}
		});
		x = nextX != null ? nextX : x;
		y = nextY != null ? nextY : y;
		middlewareData[name] = {
			...middlewareData[name],
			...data
		};
		if (reset && resetCount < MAX_RESET_COUNT) {
			resetCount++;
			if (typeof reset === "object") {
				if (reset.placement) statefulPlacement = reset.placement;
				if (reset.rects) rects = reset.rects === true ? await platform.getElementRects({
					reference,
					floating,
					strategy
				}) : reset.rects;
				({x, y} = computeCoordsFromPlacement(rects, statefulPlacement, rtl));
			}
			i = -1;
		}
	}
	return {
		x,
		y,
		placement: statefulPlacement,
		strategy,
		middlewareData
	};
};
/**
* Provides data to position an inner element of the floating element so that it
* appears centered to the reference element.
* @see https://floating-ui.com/docs/arrow
*/
var arrow$1 = (options) => ({
	name: "arrow",
	options,
	async fn(state) {
		const { x, y, placement, rects, platform, elements, middlewareData } = state;
		const { element, padding = 0 } = evaluate(options, state) || {};
		if (element == null) return {};
		const paddingObject = getPaddingObject(padding);
		const coords = {
			x,
			y
		};
		const axis = getAlignmentAxis(placement);
		const length = getAxisLength(axis);
		const arrowDimensions = await platform.getDimensions(element);
		const isYAxis = axis === "y";
		const minProp = isYAxis ? "top" : "left";
		const maxProp = isYAxis ? "bottom" : "right";
		const clientProp = isYAxis ? "clientHeight" : "clientWidth";
		const endDiff = rects.reference[length] + rects.reference[axis] - coords[axis] - rects.floating[length];
		const startDiff = coords[axis] - rects.reference[axis];
		const arrowOffsetParent = await (platform.getOffsetParent == null ? void 0 : platform.getOffsetParent(element));
		let clientSize = arrowOffsetParent ? arrowOffsetParent[clientProp] : 0;
		if (!clientSize || !await (platform.isElement == null ? void 0 : platform.isElement(arrowOffsetParent))) clientSize = elements.floating[clientProp] || rects.floating[length];
		const centerToReference = endDiff / 2 - startDiff / 2;
		const largestPossiblePadding = clientSize / 2 - arrowDimensions[length] / 2 - 1;
		const minPadding = min(paddingObject[minProp], largestPossiblePadding);
		const maxPadding = min(paddingObject[maxProp], largestPossiblePadding);
		const min$1 = minPadding;
		const max = clientSize - arrowDimensions[length] - maxPadding;
		const center = clientSize / 2 - arrowDimensions[length] / 2 + centerToReference;
		const offset = clamp(min$1, center, max);
		const shouldAddOffset = !middlewareData.arrow && getAlignment(placement) != null && center !== offset && rects.reference[length] / 2 - (center < min$1 ? minPadding : maxPadding) - arrowDimensions[length] / 2 < 0;
		const alignmentOffset = shouldAddOffset ? center < min$1 ? center - min$1 : center - max : 0;
		return {
			[axis]: coords[axis] + alignmentOffset,
			data: {
				[axis]: offset,
				centerOffset: center - offset - alignmentOffset,
				...shouldAddOffset && { alignmentOffset }
			},
			reset: shouldAddOffset
		};
	}
});
/**
* Optimizes the visibility of the floating element by flipping the `placement`
* in order to keep it in view when the preferred placement(s) will overflow the
* clipping boundary. Alternative to `autoPlacement`.
* @see https://floating-ui.com/docs/flip
*/
var flip$1 = function(options) {
	if (options === void 0) options = {};
	return {
		name: "flip",
		options,
		async fn(state) {
			var _middlewareData$arrow, _middlewareData$flip;
			const { placement, middlewareData, rects, initialPlacement, platform, elements } = state;
			const { mainAxis: checkMainAxis = true, crossAxis: checkCrossAxis = true, fallbackPlacements: specifiedFallbackPlacements, fallbackStrategy = "bestFit", fallbackAxisSideDirection = "none", flipAlignment = true, ...detectOverflowOptions } = evaluate(options, state);
			if ((_middlewareData$arrow = middlewareData.arrow) != null && _middlewareData$arrow.alignmentOffset) return {};
			const side = getSide$1(placement);
			const initialSideAxis = getSideAxis(initialPlacement);
			const isBasePlacement = getSide$1(initialPlacement) === initialPlacement;
			const rtl = await (platform.isRTL == null ? void 0 : platform.isRTL(elements.floating));
			const fallbackPlacements = specifiedFallbackPlacements || (isBasePlacement || !flipAlignment ? [getOppositePlacement(initialPlacement)] : getExpandedPlacements(initialPlacement));
			const hasFallbackAxisSideDirection = fallbackAxisSideDirection !== "none";
			if (!specifiedFallbackPlacements && hasFallbackAxisSideDirection) fallbackPlacements.push(...getOppositeAxisPlacements(initialPlacement, flipAlignment, fallbackAxisSideDirection, rtl));
			const placements = [initialPlacement, ...fallbackPlacements];
			const overflow = await platform.detectOverflow(state, detectOverflowOptions);
			const overflows = [];
			let overflowsData = ((_middlewareData$flip = middlewareData.flip) == null ? void 0 : _middlewareData$flip.overflows) || [];
			if (checkMainAxis) overflows.push(overflow[side]);
			if (checkCrossAxis) {
				const sides = getAlignmentSides(placement, rects, rtl);
				overflows.push(overflow[sides[0]], overflow[sides[1]]);
			}
			overflowsData = [...overflowsData, {
				placement,
				overflows
			}];
			if (!overflows.every((side) => side <= 0)) {
				var _middlewareData$flip2, _overflowsData$filter;
				const nextIndex = (((_middlewareData$flip2 = middlewareData.flip) == null ? void 0 : _middlewareData$flip2.index) || 0) + 1;
				const nextPlacement = placements[nextIndex];
				if (nextPlacement) {
					if (!(checkCrossAxis === "alignment" ? initialSideAxis !== getSideAxis(nextPlacement) : false) || overflowsData.every((d) => getSideAxis(d.placement) === initialSideAxis ? d.overflows[0] > 0 : true)) return {
						data: {
							index: nextIndex,
							overflows: overflowsData
						},
						reset: { placement: nextPlacement }
					};
				}
				let resetPlacement = (_overflowsData$filter = overflowsData.filter((d) => d.overflows[0] <= 0).sort((a, b) => a.overflows[1] - b.overflows[1])[0]) == null ? void 0 : _overflowsData$filter.placement;
				if (!resetPlacement) switch (fallbackStrategy) {
					case "bestFit": {
						var _overflowsData$filter2;
						const placement = (_overflowsData$filter2 = overflowsData.filter((d) => {
							if (hasFallbackAxisSideDirection) {
								const currentSideAxis = getSideAxis(d.placement);
								return currentSideAxis === initialSideAxis || currentSideAxis === "y";
							}
							return true;
						}).map((d) => [d.placement, d.overflows.filter((overflow) => overflow > 0).reduce((acc, overflow) => acc + overflow, 0)]).sort((a, b) => a[1] - b[1])[0]) == null ? void 0 : _overflowsData$filter2[0];
						if (placement) resetPlacement = placement;
						break;
					}
					case "initialPlacement":
						resetPlacement = initialPlacement;
						break;
				}
				if (placement !== resetPlacement) return { reset: { placement: resetPlacement } };
			}
			return {};
		}
	};
};
function getSideOffsets(overflow, rect) {
	return {
		top: overflow.top - rect.height,
		right: overflow.right - rect.width,
		bottom: overflow.bottom - rect.height,
		left: overflow.left - rect.width
	};
}
function isAnySideFullyClipped(overflow) {
	return sides.some((side) => overflow[side] >= 0);
}
/**
* Provides data to hide the floating element in applicable situations, such as
* when it is not in the same clipping context as the reference element.
* @see https://floating-ui.com/docs/hide
*/
var hide$1 = function(options) {
	if (options === void 0) options = {};
	return {
		name: "hide",
		options,
		async fn(state) {
			const { rects, platform } = state;
			const { strategy = "referenceHidden", ...detectOverflowOptions } = evaluate(options, state);
			switch (strategy) {
				case "referenceHidden": {
					const offsets = getSideOffsets(await platform.detectOverflow(state, {
						...detectOverflowOptions,
						elementContext: "reference"
					}), rects.reference);
					return { data: {
						referenceHiddenOffsets: offsets,
						referenceHidden: isAnySideFullyClipped(offsets)
					} };
				}
				case "escaped": {
					const offsets = getSideOffsets(await platform.detectOverflow(state, {
						...detectOverflowOptions,
						altBoundary: true
					}), rects.floating);
					return { data: {
						escapedOffsets: offsets,
						escaped: isAnySideFullyClipped(offsets)
					} };
				}
				default: return {};
			}
		}
	};
};
var originSides = /* @__PURE__ */ new Set(["left", "top"]);
async function convertValueToCoords(state, options) {
	const { placement, platform, elements } = state;
	const rtl = await (platform.isRTL == null ? void 0 : platform.isRTL(elements.floating));
	const side = getSide$1(placement);
	const alignment = getAlignment(placement);
	const isVertical = getSideAxis(placement) === "y";
	const mainAxisMulti = originSides.has(side) ? -1 : 1;
	const crossAxisMulti = rtl && isVertical ? -1 : 1;
	const rawValue = evaluate(options, state);
	let { mainAxis, crossAxis, alignmentAxis } = typeof rawValue === "number" ? {
		mainAxis: rawValue,
		crossAxis: 0,
		alignmentAxis: null
	} : {
		mainAxis: rawValue.mainAxis || 0,
		crossAxis: rawValue.crossAxis || 0,
		alignmentAxis: rawValue.alignmentAxis
	};
	if (alignment && typeof alignmentAxis === "number") crossAxis = alignment === "end" ? alignmentAxis * -1 : alignmentAxis;
	return isVertical ? {
		x: crossAxis * crossAxisMulti,
		y: mainAxis * mainAxisMulti
	} : {
		x: mainAxis * mainAxisMulti,
		y: crossAxis * crossAxisMulti
	};
}
/**
* Modifies the placement by translating the floating element along the
* specified axes.
* A number (shorthand for `mainAxis` or distance), or an axes configuration
* object may be passed.
* @see https://floating-ui.com/docs/offset
*/
var offset$1 = function(options) {
	if (options === void 0) options = 0;
	return {
		name: "offset",
		options,
		async fn(state) {
			var _middlewareData$offse, _middlewareData$arrow;
			const { x, y, placement, middlewareData } = state;
			const diffCoords = await convertValueToCoords(state, options);
			if (placement === ((_middlewareData$offse = middlewareData.offset) == null ? void 0 : _middlewareData$offse.placement) && (_middlewareData$arrow = middlewareData.arrow) != null && _middlewareData$arrow.alignmentOffset) return {};
			return {
				x: x + diffCoords.x,
				y: y + diffCoords.y,
				data: {
					...diffCoords,
					placement
				}
			};
		}
	};
};
/**
* Optimizes the visibility of the floating element by shifting it in order to
* keep it in view when it will overflow the clipping boundary.
* @see https://floating-ui.com/docs/shift
*/
var shift$1 = function(options) {
	if (options === void 0) options = {};
	return {
		name: "shift",
		options,
		async fn(state) {
			const { x, y, placement, platform } = state;
			const { mainAxis: checkMainAxis = true, crossAxis: checkCrossAxis = false, limiter = { fn: (_ref) => {
				let { x, y } = _ref;
				return {
					x,
					y
				};
			} }, ...detectOverflowOptions } = evaluate(options, state);
			const coords = {
				x,
				y
			};
			const overflow = await platform.detectOverflow(state, detectOverflowOptions);
			const crossAxis = getSideAxis(getSide$1(placement));
			const mainAxis = getOppositeAxis(crossAxis);
			let mainAxisCoord = coords[mainAxis];
			let crossAxisCoord = coords[crossAxis];
			if (checkMainAxis) {
				const minSide = mainAxis === "y" ? "top" : "left";
				const maxSide = mainAxis === "y" ? "bottom" : "right";
				const min = mainAxisCoord + overflow[minSide];
				const max = mainAxisCoord - overflow[maxSide];
				mainAxisCoord = clamp(min, mainAxisCoord, max);
			}
			if (checkCrossAxis) {
				const minSide = crossAxis === "y" ? "top" : "left";
				const maxSide = crossAxis === "y" ? "bottom" : "right";
				const min = crossAxisCoord + overflow[minSide];
				const max = crossAxisCoord - overflow[maxSide];
				crossAxisCoord = clamp(min, crossAxisCoord, max);
			}
			const limitedCoords = limiter.fn({
				...state,
				[mainAxis]: mainAxisCoord,
				[crossAxis]: crossAxisCoord
			});
			return {
				...limitedCoords,
				data: {
					x: limitedCoords.x - x,
					y: limitedCoords.y - y,
					enabled: {
						[mainAxis]: checkMainAxis,
						[crossAxis]: checkCrossAxis
					}
				}
			};
		}
	};
};
/**
* Built-in `limiter` that will stop `shift()` at a certain point.
*/
var limitShift$1 = function(options) {
	if (options === void 0) options = {};
	return {
		options,
		fn(state) {
			const { x, y, placement, rects, middlewareData } = state;
			const { offset = 0, mainAxis: checkMainAxis = true, crossAxis: checkCrossAxis = true } = evaluate(options, state);
			const coords = {
				x,
				y
			};
			const crossAxis = getSideAxis(placement);
			const mainAxis = getOppositeAxis(crossAxis);
			let mainAxisCoord = coords[mainAxis];
			let crossAxisCoord = coords[crossAxis];
			const rawOffset = evaluate(offset, state);
			const computedOffset = typeof rawOffset === "number" ? {
				mainAxis: rawOffset,
				crossAxis: 0
			} : {
				mainAxis: 0,
				crossAxis: 0,
				...rawOffset
			};
			if (checkMainAxis) {
				const len = mainAxis === "y" ? "height" : "width";
				const limitMin = rects.reference[mainAxis] - rects.floating[len] + computedOffset.mainAxis;
				const limitMax = rects.reference[mainAxis] + rects.reference[len] - computedOffset.mainAxis;
				if (mainAxisCoord < limitMin) mainAxisCoord = limitMin;
				else if (mainAxisCoord > limitMax) mainAxisCoord = limitMax;
			}
			if (checkCrossAxis) {
				var _middlewareData$offse, _middlewareData$offse2;
				const len = mainAxis === "y" ? "width" : "height";
				const isOriginSide = originSides.has(getSide$1(placement));
				const limitMin = rects.reference[crossAxis] - rects.floating[len] + (isOriginSide ? ((_middlewareData$offse = middlewareData.offset) == null ? void 0 : _middlewareData$offse[crossAxis]) || 0 : 0) + (isOriginSide ? 0 : computedOffset.crossAxis);
				const limitMax = rects.reference[crossAxis] + rects.reference[len] + (isOriginSide ? 0 : ((_middlewareData$offse2 = middlewareData.offset) == null ? void 0 : _middlewareData$offse2[crossAxis]) || 0) - (isOriginSide ? computedOffset.crossAxis : 0);
				if (crossAxisCoord < limitMin) crossAxisCoord = limitMin;
				else if (crossAxisCoord > limitMax) crossAxisCoord = limitMax;
			}
			return {
				[mainAxis]: mainAxisCoord,
				[crossAxis]: crossAxisCoord
			};
		}
	};
};
/**
* Provides data that allows you to change the size of the floating element —
* for instance, prevent it from overflowing the clipping boundary or match the
* width of the reference element.
* @see https://floating-ui.com/docs/size
*/
var size$1 = function(options) {
	if (options === void 0) options = {};
	return {
		name: "size",
		options,
		async fn(state) {
			var _state$middlewareData, _state$middlewareData2;
			const { placement, rects, platform, elements } = state;
			const { apply = () => {}, ...detectOverflowOptions } = evaluate(options, state);
			const overflow = await platform.detectOverflow(state, detectOverflowOptions);
			const side = getSide$1(placement);
			const alignment = getAlignment(placement);
			const isYAxis = getSideAxis(placement) === "y";
			const { width, height } = rects.floating;
			let heightSide;
			let widthSide;
			if (side === "top" || side === "bottom") {
				heightSide = side;
				widthSide = alignment === (await (platform.isRTL == null ? void 0 : platform.isRTL(elements.floating)) ? "start" : "end") ? "left" : "right";
			} else {
				widthSide = side;
				heightSide = alignment === "end" ? "top" : "bottom";
			}
			const maximumClippingHeight = height - overflow.top - overflow.bottom;
			const maximumClippingWidth = width - overflow.left - overflow.right;
			const overflowAvailableHeight = min(height - overflow[heightSide], maximumClippingHeight);
			const overflowAvailableWidth = min(width - overflow[widthSide], maximumClippingWidth);
			const noShift = !state.middlewareData.shift;
			let availableHeight = overflowAvailableHeight;
			let availableWidth = overflowAvailableWidth;
			if ((_state$middlewareData = state.middlewareData.shift) != null && _state$middlewareData.enabled.x) availableWidth = maximumClippingWidth;
			if ((_state$middlewareData2 = state.middlewareData.shift) != null && _state$middlewareData2.enabled.y) availableHeight = maximumClippingHeight;
			if (noShift && !alignment) {
				const xMin = max(overflow.left, 0);
				const xMax = max(overflow.right, 0);
				const yMin = max(overflow.top, 0);
				const yMax = max(overflow.bottom, 0);
				if (isYAxis) availableWidth = width - 2 * (xMin !== 0 || xMax !== 0 ? xMin + xMax : max(overflow.left, overflow.right));
				else availableHeight = height - 2 * (yMin !== 0 || yMax !== 0 ? yMin + yMax : max(overflow.top, overflow.bottom));
			}
			await apply({
				...state,
				availableWidth,
				availableHeight
			});
			const nextDimensions = await platform.getDimensions(elements.floating);
			if (width !== nextDimensions.width || height !== nextDimensions.height) return { reset: { rects: true } };
			return {};
		}
	};
};
//#endregion
//#region node_modules/@floating-ui/utils/dist/floating-ui.utils.dom.mjs
function hasWindow() {
	return typeof window !== "undefined";
}
function getNodeName(node) {
	if (isNode(node)) return (node.nodeName || "").toLowerCase();
	return "#document";
}
function getWindow(node) {
	var _node$ownerDocument;
	return (node == null || (_node$ownerDocument = node.ownerDocument) == null ? void 0 : _node$ownerDocument.defaultView) || window;
}
function getDocumentElement(node) {
	var _ref;
	return (_ref = (isNode(node) ? node.ownerDocument : node.document) || window.document) == null ? void 0 : _ref.documentElement;
}
function isNode(value) {
	if (!hasWindow()) return false;
	return value instanceof Node || value instanceof getWindow(value).Node;
}
function isElement(value) {
	if (!hasWindow()) return false;
	return value instanceof Element || value instanceof getWindow(value).Element;
}
function isHTMLElement(value) {
	if (!hasWindow()) return false;
	return value instanceof HTMLElement || value instanceof getWindow(value).HTMLElement;
}
function isShadowRoot(value) {
	if (!hasWindow() || typeof ShadowRoot === "undefined") return false;
	return value instanceof ShadowRoot || value instanceof getWindow(value).ShadowRoot;
}
function isOverflowElement(element) {
	const { overflow, overflowX, overflowY, display } = getComputedStyle$1(element);
	return /auto|scroll|overlay|hidden|clip/.test(overflow + overflowY + overflowX) && display !== "inline" && display !== "contents";
}
function isTableElement(element) {
	return /^(table|td|th)$/.test(getNodeName(element));
}
function isTopLayer(element) {
	try {
		if (element.matches(":popover-open")) return true;
	} catch (_e) {}
	try {
		return element.matches(":modal");
	} catch (_e) {
		return false;
	}
}
var willChangeRe = /transform|translate|scale|rotate|perspective|filter/;
var containRe = /paint|layout|strict|content/;
var isNotNone = (value) => !!value && value !== "none";
var isWebKitValue;
function isContainingBlock(elementOrCss) {
	const css = isElement(elementOrCss) ? getComputedStyle$1(elementOrCss) : elementOrCss;
	return isNotNone(css.transform) || isNotNone(css.translate) || isNotNone(css.scale) || isNotNone(css.rotate) || isNotNone(css.perspective) || !isWebKit() && (isNotNone(css.backdropFilter) || isNotNone(css.filter)) || willChangeRe.test(css.willChange || "") || containRe.test(css.contain || "");
}
function getContainingBlock(element) {
	let currentNode = getParentNode(element);
	while (isHTMLElement(currentNode) && !isLastTraversableNode(currentNode)) {
		if (isContainingBlock(currentNode)) return currentNode;
		else if (isTopLayer(currentNode)) return null;
		currentNode = getParentNode(currentNode);
	}
	return null;
}
function isWebKit() {
	if (isWebKitValue == null) isWebKitValue = typeof CSS !== "undefined" && CSS.supports && CSS.supports("-webkit-backdrop-filter", "none");
	return isWebKitValue;
}
function isLastTraversableNode(node) {
	return /^(html|body|#document)$/.test(getNodeName(node));
}
function getComputedStyle$1(element) {
	return getWindow(element).getComputedStyle(element);
}
function getNodeScroll(element) {
	if (isElement(element)) return {
		scrollLeft: element.scrollLeft,
		scrollTop: element.scrollTop
	};
	return {
		scrollLeft: element.scrollX,
		scrollTop: element.scrollY
	};
}
function getParentNode(node) {
	if (getNodeName(node) === "html") return node;
	const result = node.assignedSlot || node.parentNode || isShadowRoot(node) && node.host || getDocumentElement(node);
	return isShadowRoot(result) ? result.host : result;
}
function getNearestOverflowAncestor(node) {
	const parentNode = getParentNode(node);
	if (isLastTraversableNode(parentNode)) return node.ownerDocument ? node.ownerDocument.body : node.body;
	if (isHTMLElement(parentNode) && isOverflowElement(parentNode)) return parentNode;
	return getNearestOverflowAncestor(parentNode);
}
function getOverflowAncestors(node, list, traverseIframes) {
	var _node$ownerDocument2;
	if (list === void 0) list = [];
	if (traverseIframes === void 0) traverseIframes = true;
	const scrollableAncestor = getNearestOverflowAncestor(node);
	const isBody = scrollableAncestor === ((_node$ownerDocument2 = node.ownerDocument) == null ? void 0 : _node$ownerDocument2.body);
	const win = getWindow(scrollableAncestor);
	if (isBody) {
		const frameElement = getFrameElement(win);
		return list.concat(win, win.visualViewport || [], isOverflowElement(scrollableAncestor) ? scrollableAncestor : [], frameElement && traverseIframes ? getOverflowAncestors(frameElement) : []);
	} else return list.concat(scrollableAncestor, getOverflowAncestors(scrollableAncestor, [], traverseIframes));
}
function getFrameElement(win) {
	return win.parent && Object.getPrototypeOf(win.parent) ? win.frameElement : null;
}
//#endregion
//#region node_modules/@floating-ui/dom/dist/floating-ui.dom.mjs
function getCssDimensions(element) {
	const css = getComputedStyle$1(element);
	let width = parseFloat(css.width) || 0;
	let height = parseFloat(css.height) || 0;
	const hasOffset = isHTMLElement(element);
	const offsetWidth = hasOffset ? element.offsetWidth : width;
	const offsetHeight = hasOffset ? element.offsetHeight : height;
	const shouldFallback = round(width) !== offsetWidth || round(height) !== offsetHeight;
	if (shouldFallback) {
		width = offsetWidth;
		height = offsetHeight;
	}
	return {
		width,
		height,
		$: shouldFallback
	};
}
function unwrapElement(element) {
	return !isElement(element) ? element.contextElement : element;
}
function getScale(element) {
	const domElement = unwrapElement(element);
	if (!isHTMLElement(domElement)) return createCoords(1);
	const rect = domElement.getBoundingClientRect();
	const { width, height, $ } = getCssDimensions(domElement);
	let x = ($ ? round(rect.width) : rect.width) / width;
	let y = ($ ? round(rect.height) : rect.height) / height;
	if (!x || !Number.isFinite(x)) x = 1;
	if (!y || !Number.isFinite(y)) y = 1;
	return {
		x,
		y
	};
}
var noOffsets = /* @__PURE__ */ createCoords(0);
function getVisualOffsets(element) {
	const win = getWindow(element);
	if (!isWebKit() || !win.visualViewport) return noOffsets;
	return {
		x: win.visualViewport.offsetLeft,
		y: win.visualViewport.offsetTop
	};
}
function shouldAddVisualOffsets(element, isFixed, floatingOffsetParent) {
	if (isFixed === void 0) isFixed = false;
	if (!floatingOffsetParent || isFixed && floatingOffsetParent !== getWindow(element)) return false;
	return isFixed;
}
function getBoundingClientRect(element, includeScale, isFixedStrategy, offsetParent) {
	if (includeScale === void 0) includeScale = false;
	if (isFixedStrategy === void 0) isFixedStrategy = false;
	const clientRect = element.getBoundingClientRect();
	const domElement = unwrapElement(element);
	let scale = createCoords(1);
	if (includeScale) if (offsetParent) {
		if (isElement(offsetParent)) scale = getScale(offsetParent);
	} else scale = getScale(element);
	const visualOffsets = shouldAddVisualOffsets(domElement, isFixedStrategy, offsetParent) ? getVisualOffsets(domElement) : createCoords(0);
	let x = (clientRect.left + visualOffsets.x) / scale.x;
	let y = (clientRect.top + visualOffsets.y) / scale.y;
	let width = clientRect.width / scale.x;
	let height = clientRect.height / scale.y;
	if (domElement) {
		const win = getWindow(domElement);
		const offsetWin = offsetParent && isElement(offsetParent) ? getWindow(offsetParent) : offsetParent;
		let currentWin = win;
		let currentIFrame = getFrameElement(currentWin);
		while (currentIFrame && offsetParent && offsetWin !== currentWin) {
			const iframeScale = getScale(currentIFrame);
			const iframeRect = currentIFrame.getBoundingClientRect();
			const css = getComputedStyle$1(currentIFrame);
			const left = iframeRect.left + (currentIFrame.clientLeft + parseFloat(css.paddingLeft)) * iframeScale.x;
			const top = iframeRect.top + (currentIFrame.clientTop + parseFloat(css.paddingTop)) * iframeScale.y;
			x *= iframeScale.x;
			y *= iframeScale.y;
			width *= iframeScale.x;
			height *= iframeScale.y;
			x += left;
			y += top;
			currentWin = getWindow(currentIFrame);
			currentIFrame = getFrameElement(currentWin);
		}
	}
	return rectToClientRect({
		width,
		height,
		x,
		y
	});
}
function getWindowScrollBarX(element, rect) {
	const leftScroll = getNodeScroll(element).scrollLeft;
	if (!rect) return getBoundingClientRect(getDocumentElement(element)).left + leftScroll;
	return rect.left + leftScroll;
}
function getHTMLOffset(documentElement, scroll) {
	const htmlRect = documentElement.getBoundingClientRect();
	return {
		x: htmlRect.left + scroll.scrollLeft - getWindowScrollBarX(documentElement, htmlRect),
		y: htmlRect.top + scroll.scrollTop
	};
}
function convertOffsetParentRelativeRectToViewportRelativeRect(_ref) {
	let { elements, rect, offsetParent, strategy } = _ref;
	const isFixed = strategy === "fixed";
	const documentElement = getDocumentElement(offsetParent);
	const topLayer = elements ? isTopLayer(elements.floating) : false;
	if (offsetParent === documentElement || topLayer && isFixed) return rect;
	let scroll = {
		scrollLeft: 0,
		scrollTop: 0
	};
	let scale = createCoords(1);
	const offsets = createCoords(0);
	const isOffsetParentAnElement = isHTMLElement(offsetParent);
	if (isOffsetParentAnElement || !isOffsetParentAnElement && !isFixed) {
		if (getNodeName(offsetParent) !== "body" || isOverflowElement(documentElement)) scroll = getNodeScroll(offsetParent);
		if (isOffsetParentAnElement) {
			const offsetRect = getBoundingClientRect(offsetParent);
			scale = getScale(offsetParent);
			offsets.x = offsetRect.x + offsetParent.clientLeft;
			offsets.y = offsetRect.y + offsetParent.clientTop;
		}
	}
	const htmlOffset = documentElement && !isOffsetParentAnElement && !isFixed ? getHTMLOffset(documentElement, scroll) : createCoords(0);
	return {
		width: rect.width * scale.x,
		height: rect.height * scale.y,
		x: rect.x * scale.x - scroll.scrollLeft * scale.x + offsets.x + htmlOffset.x,
		y: rect.y * scale.y - scroll.scrollTop * scale.y + offsets.y + htmlOffset.y
	};
}
function getClientRects(element) {
	return Array.from(element.getClientRects());
}
function getDocumentRect(element) {
	const html = getDocumentElement(element);
	const scroll = getNodeScroll(element);
	const body = element.ownerDocument.body;
	const width = max(html.scrollWidth, html.clientWidth, body.scrollWidth, body.clientWidth);
	const height = max(html.scrollHeight, html.clientHeight, body.scrollHeight, body.clientHeight);
	let x = -scroll.scrollLeft + getWindowScrollBarX(element);
	const y = -scroll.scrollTop;
	if (getComputedStyle$1(body).direction === "rtl") x += max(html.clientWidth, body.clientWidth) - width;
	return {
		width,
		height,
		x,
		y
	};
}
var SCROLLBAR_MAX = 25;
function getViewportRect(element, strategy) {
	const win = getWindow(element);
	const html = getDocumentElement(element);
	const visualViewport = win.visualViewport;
	let width = html.clientWidth;
	let height = html.clientHeight;
	let x = 0;
	let y = 0;
	if (visualViewport) {
		width = visualViewport.width;
		height = visualViewport.height;
		const visualViewportBased = isWebKit();
		if (!visualViewportBased || visualViewportBased && strategy === "fixed") {
			x = visualViewport.offsetLeft;
			y = visualViewport.offsetTop;
		}
	}
	const windowScrollbarX = getWindowScrollBarX(html);
	if (windowScrollbarX <= 0) {
		const doc = html.ownerDocument;
		const body = doc.body;
		const bodyStyles = getComputedStyle(body);
		const bodyMarginInline = doc.compatMode === "CSS1Compat" ? parseFloat(bodyStyles.marginLeft) + parseFloat(bodyStyles.marginRight) || 0 : 0;
		const clippingStableScrollbarWidth = Math.abs(html.clientWidth - body.clientWidth - bodyMarginInline);
		if (clippingStableScrollbarWidth <= SCROLLBAR_MAX) width -= clippingStableScrollbarWidth;
	} else if (windowScrollbarX <= SCROLLBAR_MAX) width += windowScrollbarX;
	return {
		width,
		height,
		x,
		y
	};
}
function getInnerBoundingClientRect(element, strategy) {
	const clientRect = getBoundingClientRect(element, true, strategy === "fixed");
	const top = clientRect.top + element.clientTop;
	const left = clientRect.left + element.clientLeft;
	const scale = isHTMLElement(element) ? getScale(element) : createCoords(1);
	return {
		width: element.clientWidth * scale.x,
		height: element.clientHeight * scale.y,
		x: left * scale.x,
		y: top * scale.y
	};
}
function getClientRectFromClippingAncestor(element, clippingAncestor, strategy) {
	let rect;
	if (clippingAncestor === "viewport") rect = getViewportRect(element, strategy);
	else if (clippingAncestor === "document") rect = getDocumentRect(getDocumentElement(element));
	else if (isElement(clippingAncestor)) rect = getInnerBoundingClientRect(clippingAncestor, strategy);
	else {
		const visualOffsets = getVisualOffsets(element);
		rect = {
			x: clippingAncestor.x - visualOffsets.x,
			y: clippingAncestor.y - visualOffsets.y,
			width: clippingAncestor.width,
			height: clippingAncestor.height
		};
	}
	return rectToClientRect(rect);
}
function hasFixedPositionAncestor(element, stopNode) {
	const parentNode = getParentNode(element);
	if (parentNode === stopNode || !isElement(parentNode) || isLastTraversableNode(parentNode)) return false;
	return getComputedStyle$1(parentNode).position === "fixed" || hasFixedPositionAncestor(parentNode, stopNode);
}
function getClippingElementAncestors(element, cache) {
	const cachedResult = cache.get(element);
	if (cachedResult) return cachedResult;
	let result = getOverflowAncestors(element, [], false).filter((el) => isElement(el) && getNodeName(el) !== "body");
	let currentContainingBlockComputedStyle = null;
	const elementIsFixed = getComputedStyle$1(element).position === "fixed";
	let currentNode = elementIsFixed ? getParentNode(element) : element;
	while (isElement(currentNode) && !isLastTraversableNode(currentNode)) {
		const computedStyle = getComputedStyle$1(currentNode);
		const currentNodeIsContaining = isContainingBlock(currentNode);
		if (!currentNodeIsContaining && computedStyle.position === "fixed") currentContainingBlockComputedStyle = null;
		if (elementIsFixed ? !currentNodeIsContaining && !currentContainingBlockComputedStyle : !currentNodeIsContaining && computedStyle.position === "static" && !!currentContainingBlockComputedStyle && (currentContainingBlockComputedStyle.position === "absolute" || currentContainingBlockComputedStyle.position === "fixed") || isOverflowElement(currentNode) && !currentNodeIsContaining && hasFixedPositionAncestor(element, currentNode)) result = result.filter((ancestor) => ancestor !== currentNode);
		else currentContainingBlockComputedStyle = computedStyle;
		currentNode = getParentNode(currentNode);
	}
	cache.set(element, result);
	return result;
}
function getClippingRect(_ref) {
	let { element, boundary, rootBoundary, strategy } = _ref;
	const clippingAncestors = [...boundary === "clippingAncestors" ? isTopLayer(element) ? [] : getClippingElementAncestors(element, this._c) : [].concat(boundary), rootBoundary];
	const firstRect = getClientRectFromClippingAncestor(element, clippingAncestors[0], strategy);
	let top = firstRect.top;
	let right = firstRect.right;
	let bottom = firstRect.bottom;
	let left = firstRect.left;
	for (let i = 1; i < clippingAncestors.length; i++) {
		const rect = getClientRectFromClippingAncestor(element, clippingAncestors[i], strategy);
		top = max(rect.top, top);
		right = min(rect.right, right);
		bottom = min(rect.bottom, bottom);
		left = max(rect.left, left);
	}
	return {
		width: right - left,
		height: bottom - top,
		x: left,
		y: top
	};
}
function getDimensions(element) {
	const { width, height } = getCssDimensions(element);
	return {
		width,
		height
	};
}
function getRectRelativeToOffsetParent(element, offsetParent, strategy) {
	const isOffsetParentAnElement = isHTMLElement(offsetParent);
	const documentElement = getDocumentElement(offsetParent);
	const isFixed = strategy === "fixed";
	const rect = getBoundingClientRect(element, true, isFixed, offsetParent);
	let scroll = {
		scrollLeft: 0,
		scrollTop: 0
	};
	const offsets = createCoords(0);
	function setLeftRTLScrollbarOffset() {
		offsets.x = getWindowScrollBarX(documentElement);
	}
	if (isOffsetParentAnElement || !isOffsetParentAnElement && !isFixed) {
		if (getNodeName(offsetParent) !== "body" || isOverflowElement(documentElement)) scroll = getNodeScroll(offsetParent);
		if (isOffsetParentAnElement) {
			const offsetRect = getBoundingClientRect(offsetParent, true, isFixed, offsetParent);
			offsets.x = offsetRect.x + offsetParent.clientLeft;
			offsets.y = offsetRect.y + offsetParent.clientTop;
		} else if (documentElement) setLeftRTLScrollbarOffset();
	}
	if (isFixed && !isOffsetParentAnElement && documentElement) setLeftRTLScrollbarOffset();
	const htmlOffset = documentElement && !isOffsetParentAnElement && !isFixed ? getHTMLOffset(documentElement, scroll) : createCoords(0);
	return {
		x: rect.left + scroll.scrollLeft - offsets.x - htmlOffset.x,
		y: rect.top + scroll.scrollTop - offsets.y - htmlOffset.y,
		width: rect.width,
		height: rect.height
	};
}
function isStaticPositioned(element) {
	return getComputedStyle$1(element).position === "static";
}
function getTrueOffsetParent(element, polyfill) {
	if (!isHTMLElement(element) || getComputedStyle$1(element).position === "fixed") return null;
	if (polyfill) return polyfill(element);
	let rawOffsetParent = element.offsetParent;
	if (getDocumentElement(element) === rawOffsetParent) rawOffsetParent = rawOffsetParent.ownerDocument.body;
	return rawOffsetParent;
}
function getOffsetParent(element, polyfill) {
	const win = getWindow(element);
	if (isTopLayer(element)) return win;
	if (!isHTMLElement(element)) {
		let svgOffsetParent = getParentNode(element);
		while (svgOffsetParent && !isLastTraversableNode(svgOffsetParent)) {
			if (isElement(svgOffsetParent) && !isStaticPositioned(svgOffsetParent)) return svgOffsetParent;
			svgOffsetParent = getParentNode(svgOffsetParent);
		}
		return win;
	}
	let offsetParent = getTrueOffsetParent(element, polyfill);
	while (offsetParent && isTableElement(offsetParent) && isStaticPositioned(offsetParent)) offsetParent = getTrueOffsetParent(offsetParent, polyfill);
	if (offsetParent && isLastTraversableNode(offsetParent) && isStaticPositioned(offsetParent) && !isContainingBlock(offsetParent)) return win;
	return offsetParent || getContainingBlock(element) || win;
}
var getElementRects = async function(data) {
	const getOffsetParentFn = this.getOffsetParent || getOffsetParent;
	const getDimensionsFn = this.getDimensions;
	const floatingDimensions = await getDimensionsFn(data.floating);
	return {
		reference: getRectRelativeToOffsetParent(data.reference, await getOffsetParentFn(data.floating), data.strategy),
		floating: {
			x: 0,
			y: 0,
			width: floatingDimensions.width,
			height: floatingDimensions.height
		}
	};
};
function isRTL(element) {
	return getComputedStyle$1(element).direction === "rtl";
}
var platform = {
	convertOffsetParentRelativeRectToViewportRelativeRect,
	getDocumentElement,
	getClippingRect,
	getOffsetParent,
	getElementRects,
	getClientRects,
	getDimensions,
	getScale,
	isElement,
	isRTL
};
function rectsAreEqual(a, b) {
	return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
}
function observeMove(element, onMove) {
	let io = null;
	let timeoutId;
	const root = getDocumentElement(element);
	function cleanup() {
		var _io;
		clearTimeout(timeoutId);
		(_io = io) == null || _io.disconnect();
		io = null;
	}
	function refresh(skip, threshold) {
		if (skip === void 0) skip = false;
		if (threshold === void 0) threshold = 1;
		cleanup();
		const elementRectForRootMargin = element.getBoundingClientRect();
		const { left, top, width, height } = elementRectForRootMargin;
		if (!skip) onMove();
		if (!width || !height) return;
		const insetTop = floor(top);
		const insetRight = floor(root.clientWidth - (left + width));
		const insetBottom = floor(root.clientHeight - (top + height));
		const insetLeft = floor(left);
		const options = {
			rootMargin: -insetTop + "px " + -insetRight + "px " + -insetBottom + "px " + -insetLeft + "px",
			threshold: max(0, min(1, threshold)) || 1
		};
		let isFirstUpdate = true;
		function handleObserve(entries) {
			const ratio = entries[0].intersectionRatio;
			if (ratio !== threshold) {
				if (!isFirstUpdate) return refresh();
				if (!ratio) timeoutId = setTimeout(() => {
					refresh(false, 1e-7);
				}, 1e3);
				else refresh(false, ratio);
			}
			if (ratio === 1 && !rectsAreEqual(elementRectForRootMargin, element.getBoundingClientRect())) refresh();
			isFirstUpdate = false;
		}
		try {
			io = new IntersectionObserver(handleObserve, {
				...options,
				root: root.ownerDocument
			});
		} catch (_e) {
			io = new IntersectionObserver(handleObserve, options);
		}
		io.observe(element);
	}
	refresh(true);
	return cleanup;
}
/**
* Automatically updates the position of the floating element when necessary.
* Should only be called when the floating element is mounted on the DOM or
* visible on the screen.
* @returns cleanup function that should be invoked when the floating element is
* removed from the DOM or hidden from the screen.
* @see https://floating-ui.com/docs/autoUpdate
*/
function autoUpdate(reference, floating, update, options) {
	if (options === void 0) options = {};
	const { ancestorScroll = true, ancestorResize = true, elementResize = typeof ResizeObserver === "function", layoutShift = typeof IntersectionObserver === "function", animationFrame = false } = options;
	const referenceEl = unwrapElement(reference);
	const ancestors = ancestorScroll || ancestorResize ? [...referenceEl ? getOverflowAncestors(referenceEl) : [], ...floating ? getOverflowAncestors(floating) : []] : [];
	ancestors.forEach((ancestor) => {
		ancestorScroll && ancestor.addEventListener("scroll", update, { passive: true });
		ancestorResize && ancestor.addEventListener("resize", update);
	});
	const cleanupIo = referenceEl && layoutShift ? observeMove(referenceEl, update) : null;
	let reobserveFrame = -1;
	let resizeObserver = null;
	if (elementResize) {
		resizeObserver = new ResizeObserver((_ref) => {
			let [firstEntry] = _ref;
			if (firstEntry && firstEntry.target === referenceEl && resizeObserver && floating) {
				resizeObserver.unobserve(floating);
				cancelAnimationFrame(reobserveFrame);
				reobserveFrame = requestAnimationFrame(() => {
					var _resizeObserver;
					(_resizeObserver = resizeObserver) == null || _resizeObserver.observe(floating);
				});
			}
			update();
		});
		if (referenceEl && !animationFrame) resizeObserver.observe(referenceEl);
		if (floating) resizeObserver.observe(floating);
	}
	let frameId;
	let prevRefRect = animationFrame ? getBoundingClientRect(reference) : null;
	if (animationFrame) frameLoop();
	function frameLoop() {
		const nextRefRect = getBoundingClientRect(reference);
		if (prevRefRect && !rectsAreEqual(prevRefRect, nextRefRect)) update();
		prevRefRect = nextRefRect;
		frameId = requestAnimationFrame(frameLoop);
	}
	update();
	return () => {
		var _resizeObserver2;
		ancestors.forEach((ancestor) => {
			ancestorScroll && ancestor.removeEventListener("scroll", update);
			ancestorResize && ancestor.removeEventListener("resize", update);
		});
		cleanupIo?.();
		(_resizeObserver2 = resizeObserver) == null || _resizeObserver2.disconnect();
		resizeObserver = null;
		if (animationFrame) cancelAnimationFrame(frameId);
	};
}
/**
* Modifies the placement by translating the floating element along the
* specified axes.
* A number (shorthand for `mainAxis` or distance), or an axes configuration
* object may be passed.
* @see https://floating-ui.com/docs/offset
*/
var offset = offset$1;
/**
* Optimizes the visibility of the floating element by shifting it in order to
* keep it in view when it will overflow the clipping boundary.
* @see https://floating-ui.com/docs/shift
*/
var shift = shift$1;
/**
* Optimizes the visibility of the floating element by flipping the `placement`
* in order to keep it in view when the preferred placement(s) will overflow the
* clipping boundary. Alternative to `autoPlacement`.
* @see https://floating-ui.com/docs/flip
*/
var flip = flip$1;
/**
* Provides data that allows you to change the size of the floating element —
* for instance, prevent it from overflowing the clipping boundary or match the
* width of the reference element.
* @see https://floating-ui.com/docs/size
*/
var size = size$1;
/**
* Provides data to hide the floating element in applicable situations, such as
* when it is not in the same clipping context as the reference element.
* @see https://floating-ui.com/docs/hide
*/
var hide = hide$1;
/**
* Provides data to position an inner element of the floating element so that it
* appears centered to the reference element.
* @see https://floating-ui.com/docs/arrow
*/
var arrow = arrow$1;
/**
* Built-in `limiter` that will stop `shift()` at a certain point.
*/
var limitShift = limitShift$1;
/**
* Computes the `x` and `y` coordinates that will place the floating element
* next to a given reference element.
*/
var computePosition = (reference, floating, options) => {
	const cache = /* @__PURE__ */ new Map();
	const mergedOptions = {
		platform,
		...options
	};
	const platformWithCache = {
		...mergedOptions.platform,
		_c: cache
	};
	return computePosition$1(reference, floating, {
		...mergedOptions,
		platform: platformWithCache
	});
};
//#endregion
//#region node_modules/bits-ui/dist/internal/floating-svelte/floating-utils.svelte.js
function get(valueOrGetValue) {
	return typeof valueOrGetValue === "function" ? valueOrGetValue() : valueOrGetValue;
}
function getDPR(element) {
	if (typeof window === "undefined") return 1;
	return (element.ownerDocument.defaultView || window).devicePixelRatio || 1;
}
function roundByDPR(element, value) {
	const dpr = getDPR(element);
	return Math.round(value * dpr) / dpr;
}
function getFloatingContentCSSVars(name) {
	return {
		[`--bits-${name}-content-transform-origin`]: `var(--bits-floating-transform-origin)`,
		[`--bits-${name}-content-available-width`]: `var(--bits-floating-available-width)`,
		[`--bits-${name}-content-available-height`]: `var(--bits-floating-available-height)`,
		[`--bits-${name}-anchor-width`]: `var(--bits-floating-anchor-width)`,
		[`--bits-${name}-anchor-height`]: `var(--bits-floating-anchor-height)`
	};
}
//#endregion
//#region node_modules/bits-ui/dist/internal/floating-svelte/use-floating.svelte.js
function useFloating(options) {
	/** Options */
	const whileElementsMountedOption = options.whileElementsMounted;
	const openOption = user_derived(() => get(options.open) ?? true);
	const middlewareOption = user_derived(() => get(options.middleware));
	const transformOption = user_derived(() => get(options.transform) ?? true);
	const placementOption = user_derived(() => get(options.placement) ?? "bottom");
	const strategyOption = user_derived(() => get(options.strategy) ?? "absolute");
	const sideOffsetOption = user_derived(() => get(options.sideOffset) ?? 0);
	const alignOffsetOption = user_derived(() => get(options.alignOffset) ?? 0);
	const reference = options.reference;
	/** State */
	let x = state$1(0);
	let y = state$1(0);
	const floating = simpleBox(null);
	let strategy = state$1(proxy(get$2(strategyOption)));
	let placement = state$1(proxy(get$2(placementOption)));
	let middlewareData = state$1(proxy({}));
	let isPositioned = state$1(false);
	let hasWhileMountedPosition = false;
	let updateRequestId = 0;
	const floatingStyles = user_derived(() => {
		const xVal = floating.current ? roundByDPR(floating.current, get$2(x)) : get$2(x);
		const yVal = floating.current ? roundByDPR(floating.current, get$2(y)) : get$2(y);
		if (get$2(transformOption)) return {
			position: get$2(strategy),
			left: "0",
			top: "0",
			transform: `translate(${xVal}px, ${yVal}px)`,
			...floating.current && getDPR(floating.current) >= 1.5 && { willChange: "transform" }
		};
		return {
			position: get$2(strategy),
			left: `${xVal}px`,
			top: `${yVal}px`
		};
	});
	/** Effects */
	let whileElementsMountedCleanup;
	function update() {
		if (reference.current === null || floating.current === null) return;
		const referenceNode = reference.current;
		const floatingNode = floating.current;
		const requestId = ++updateRequestId;
		computePosition(referenceNode, floatingNode, {
			middleware: get$2(middlewareOption),
			placement: get$2(placementOption),
			strategy: get$2(strategyOption)
		}).then((position) => {
			if (requestId !== updateRequestId) return;
			if (reference.current !== referenceNode || floating.current !== floatingNode) return;
			if (isReferenceHidden(referenceNode)) {
				set(middlewareData, {
					...get$2(middlewareData),
					hide: {
						...get$2(middlewareData).hide,
						referenceHidden: true
					}
				}, true);
				return;
			}
			if (!get$2(openOption) && get$2(x) !== 0 && get$2(y) !== 0) {
				const maxExpectedOffset = Math.max(Math.abs(get$2(sideOffsetOption)), Math.abs(get$2(alignOffsetOption)), 15);
				if (position.x <= maxExpectedOffset && position.y <= maxExpectedOffset) return;
			}
			set(x, position.x, true);
			set(y, position.y, true);
			set(strategy, position.strategy, true);
			set(placement, position.placement, true);
			set(middlewareData, position.middlewareData, true);
			set(isPositioned, true);
		});
	}
	function cleanup() {
		if (typeof whileElementsMountedCleanup === "function") {
			whileElementsMountedCleanup();
			whileElementsMountedCleanup = void 0;
		}
		updateRequestId++;
	}
	function attach() {
		cleanup();
		if (whileElementsMountedOption === void 0) {
			update();
			return;
		}
		if (!get$2(openOption)) return;
		if (reference.current === null || floating.current === null) return;
		whileElementsMountedCleanup = whileElementsMountedOption(reference.current, floating.current, update);
	}
	function reset() {
		if (!get$2(openOption) && floating.current === null) set(isPositioned, false);
	}
	function trackWhileMountedDeps() {
		return [
			get$2(middlewareOption),
			get$2(placementOption),
			get$2(strategyOption),
			get$2(sideOffsetOption),
			get$2(alignOffsetOption),
			get$2(openOption)
		];
	}
	user_effect(() => {
		if (whileElementsMountedOption !== void 0) return;
		if (!get$2(openOption)) return;
		update();
	});
	user_effect(attach);
	user_effect(() => {
		if (whileElementsMountedOption === void 0) return;
		trackWhileMountedDeps();
		if (!get$2(openOption)) {
			hasWhileMountedPosition = false;
			return;
		}
		if (!get$2(isPositioned)) {
			hasWhileMountedPosition = false;
			return;
		}
		if (!hasWhileMountedPosition) {
			hasWhileMountedPosition = true;
			return;
		}
		update();
	});
	user_effect(reset);
	user_effect(() => cleanup);
	return {
		floating,
		reference,
		get strategy() {
			return get$2(strategy);
		},
		get placement() {
			return get$2(placement);
		},
		get middlewareData() {
			return get$2(middlewareData);
		},
		get isPositioned() {
			return get$2(isPositioned);
		},
		get floatingStyles() {
			return get$2(floatingStyles);
		},
		get update() {
			return update;
		}
	};
}
function isReferenceHidden(node) {
	if (!(node instanceof Element)) return false;
	if (!node.isConnected) return true;
	if (node instanceof HTMLElement && node.hidden) return true;
	return node.getClientRects().length === 0;
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/floating-layer/use-floating-layer.svelte.js
var OPPOSITE_SIDE = {
	top: "bottom",
	right: "left",
	bottom: "top",
	left: "right"
};
var FloatingRootContext = new Context$1("Floating.Root");
var FloatingContentContext = new Context$1("Floating.Content");
var FloatingTooltipRootContext = new Context$1("Floating.Root");
var FloatingRootState = class FloatingRootState {
	static create(tooltip = false) {
		return tooltip ? FloatingTooltipRootContext.set(new FloatingRootState()) : FloatingRootContext.set(new FloatingRootState());
	}
	anchorNode = simpleBox(null);
	customAnchorNode = simpleBox(null);
	triggerNode = simpleBox(null);
	constructor() {
		user_effect(() => {
			if (this.customAnchorNode.current) if (typeof this.customAnchorNode.current === "string") this.anchorNode.current = document.querySelector(this.customAnchorNode.current);
			else this.anchorNode.current = this.customAnchorNode.current;
			else this.anchorNode.current = this.triggerNode.current;
		});
	}
};
var FloatingContentState = class FloatingContentState {
	static create(opts, tooltip = false) {
		return tooltip ? FloatingContentContext.set(new FloatingContentState(opts, FloatingTooltipRootContext.get())) : FloatingContentContext.set(new FloatingContentState(opts, FloatingRootContext.get()));
	}
	opts;
	root;
	contentRef = simpleBox(null);
	wrapperRef = simpleBox(null);
	arrowRef = simpleBox(null);
	contentAttachment = attachRef(this.contentRef);
	wrapperAttachment = attachRef(this.wrapperRef);
	arrowAttachment = attachRef(this.arrowRef);
	arrowId = simpleBox(useId());
	#transformedStyle = user_derived(() => {
		if (typeof this.opts.style === "string") return cssToStyleObj(this.opts.style);
		if (!this.opts.style) return {};
	});
	#updatePositionStrategy = void 0;
	#arrowSize = new ElementSize(() => this.arrowRef.current ?? void 0);
	#arrowWidth = user_derived(() => this.#arrowSize?.width ?? 0);
	#arrowHeight = user_derived(() => this.#arrowSize?.height ?? 0);
	#desiredPlacement = user_derived(() => this.opts.side?.current + (this.opts.align.current !== "center" ? `-${this.opts.align.current}` : ""));
	#boundary = user_derived(() => Array.isArray(this.opts.collisionBoundary.current) ? this.opts.collisionBoundary.current : [this.opts.collisionBoundary.current]);
	#hasExplicitBoundaries = user_derived(() => get$2(this.#boundary).length > 0);
	get hasExplicitBoundaries() {
		return get$2(this.#hasExplicitBoundaries);
	}
	set hasExplicitBoundaries(value) {
		set(this.#hasExplicitBoundaries, value);
	}
	#detectOverflowOptions = user_derived(() => ({
		padding: this.opts.collisionPadding.current,
		boundary: get$2(this.#boundary).filter(isNotNull),
		altBoundary: this.hasExplicitBoundaries
	}));
	get detectOverflowOptions() {
		return get$2(this.#detectOverflowOptions);
	}
	set detectOverflowOptions(value) {
		set(this.#detectOverflowOptions, value);
	}
	#availableWidth = state$1(void 0);
	#availableHeight = state$1(void 0);
	#anchorWidth = state$1(void 0);
	#anchorHeight = state$1(void 0);
	#middleware = user_derived(() => [
		offset({
			mainAxis: this.opts.sideOffset.current + get$2(this.#arrowHeight),
			alignmentAxis: this.opts.alignOffset.current
		}),
		this.opts.avoidCollisions.current && shift({
			mainAxis: true,
			crossAxis: false,
			limiter: this.opts.sticky.current === "partial" ? limitShift() : void 0,
			...this.detectOverflowOptions
		}),
		this.opts.avoidCollisions.current && flip({ ...this.detectOverflowOptions }),
		size({
			...this.detectOverflowOptions,
			apply: ({ rects, availableWidth, availableHeight }) => {
				const { width: anchorWidth, height: anchorHeight } = rects.reference;
				set(this.#availableWidth, availableWidth, true);
				set(this.#availableHeight, availableHeight, true);
				set(this.#anchorWidth, anchorWidth, true);
				set(this.#anchorHeight, anchorHeight, true);
			}
		}),
		this.arrowRef.current && arrow({
			element: this.arrowRef.current,
			padding: this.opts.arrowPadding.current
		}),
		transformOrigin({
			arrowWidth: get$2(this.#arrowWidth),
			arrowHeight: get$2(this.#arrowHeight)
		}),
		this.opts.hideWhenDetached.current && hide({
			strategy: "referenceHidden",
			...this.detectOverflowOptions
		})
	].filter(Boolean));
	get middleware() {
		return get$2(this.#middleware);
	}
	set middleware(value) {
		set(this.#middleware, value);
	}
	floating;
	#placedSide = user_derived(() => getSideFromPlacement(this.floating.placement));
	get placedSide() {
		return get$2(this.#placedSide);
	}
	set placedSide(value) {
		set(this.#placedSide, value);
	}
	#placedAlign = user_derived(() => getAlignFromPlacement(this.floating.placement));
	get placedAlign() {
		return get$2(this.#placedAlign);
	}
	set placedAlign(value) {
		set(this.#placedAlign, value);
	}
	#arrowX = user_derived(() => this.floating.middlewareData.arrow?.x ?? 0);
	get arrowX() {
		return get$2(this.#arrowX);
	}
	set arrowX(value) {
		set(this.#arrowX, value);
	}
	#arrowY = user_derived(() => this.floating.middlewareData.arrow?.y ?? 0);
	get arrowY() {
		return get$2(this.#arrowY);
	}
	set arrowY(value) {
		set(this.#arrowY, value);
	}
	#cannotCenterArrow = user_derived(() => this.floating.middlewareData.arrow?.centerOffset !== 0);
	get cannotCenterArrow() {
		return get$2(this.#cannotCenterArrow);
	}
	set cannotCenterArrow(value) {
		set(this.#cannotCenterArrow, value);
	}
	#contentZIndex = state$1();
	get contentZIndex() {
		return get$2(this.#contentZIndex);
	}
	set contentZIndex(value) {
		set(this.#contentZIndex, value, true);
	}
	#arrowBaseSide = user_derived(() => OPPOSITE_SIDE[this.placedSide]);
	get arrowBaseSide() {
		return get$2(this.#arrowBaseSide);
	}
	set arrowBaseSide(value) {
		set(this.#arrowBaseSide, value);
	}
	#wrapperProps = user_derived(() => ({
		id: this.opts.wrapperId.current,
		"data-bits-floating-content-wrapper": "",
		style: {
			...this.floating.floatingStyles,
			transform: this.floating.isPositioned ? this.floating.floatingStyles.transform : "translate(0, -200%)",
			minWidth: "max-content",
			zIndex: this.contentZIndex,
			"--bits-floating-transform-origin": `${this.floating.middlewareData.transformOrigin?.x} ${this.floating.middlewareData.transformOrigin?.y}`,
			"--bits-floating-available-width": `${get$2(this.#availableWidth)}px`,
			"--bits-floating-available-height": `${get$2(this.#availableHeight)}px`,
			"--bits-floating-anchor-width": `${get$2(this.#anchorWidth)}px`,
			"--bits-floating-anchor-height": `${get$2(this.#anchorHeight)}px`,
			...this.floating.middlewareData.hide?.referenceHidden && {
				visibility: "hidden",
				"pointer-events": "none"
			},
			...get$2(this.#transformedStyle)
		},
		dir: this.opts.dir.current,
		...this.wrapperAttachment
	}));
	get wrapperProps() {
		return get$2(this.#wrapperProps);
	}
	set wrapperProps(value) {
		set(this.#wrapperProps, value);
	}
	#props = user_derived(() => ({
		"data-side": this.placedSide,
		"data-align": this.placedAlign,
		style: styleToString({ ...get$2(this.#transformedStyle) }),
		...this.contentAttachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
	#arrowStyle = user_derived(() => ({
		position: "absolute",
		left: this.arrowX ? `${this.arrowX}px` : void 0,
		top: this.arrowY ? `${this.arrowY}px` : void 0,
		[this.arrowBaseSide]: 0,
		"transform-origin": {
			top: "",
			right: "0 0",
			bottom: "center 0",
			left: "100% 0"
		}[this.placedSide],
		transform: {
			top: "translateY(100%)",
			right: "translateY(50%) rotate(90deg) translateX(-50%)",
			bottom: "rotate(180deg)",
			left: "translateY(50%) rotate(-90deg) translateX(50%)"
		}[this.placedSide],
		visibility: this.cannotCenterArrow ? "hidden" : void 0
	}));
	get arrowStyle() {
		return get$2(this.#arrowStyle);
	}
	set arrowStyle(value) {
		set(this.#arrowStyle, value);
	}
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.#updatePositionStrategy = opts.updatePositionStrategy;
		if (opts.customAnchor) this.root.customAnchorNode.current = opts.customAnchor.current;
		watch$1(() => opts.customAnchor.current, (customAnchor) => {
			this.root.customAnchorNode.current = customAnchor;
		});
		this.floating = useFloating({
			strategy: () => this.opts.strategy.current,
			placement: () => get$2(this.#desiredPlacement),
			middleware: () => this.middleware,
			reference: this.root.anchorNode,
			whileElementsMounted: (...args) => {
				return autoUpdate(...args, { animationFrame: this.#updatePositionStrategy?.current === "always" });
			},
			open: () => this.opts.enabled.current,
			sideOffset: () => this.opts.sideOffset.current,
			alignOffset: () => this.opts.alignOffset.current
		});
		user_effect(() => {
			if (!this.floating.isPositioned) return;
			this.opts.onPlaced?.current();
		});
		watch$1(() => this.contentRef.current, (contentNode) => {
			if (!contentNode || !this.opts.enabled.current) return;
			const win = getWindow$1(contentNode);
			const rafId = win.requestAnimationFrame(() => {
				if (this.contentRef.current !== contentNode || !this.opts.enabled.current) return;
				const zIndex = win.getComputedStyle(contentNode).zIndex;
				if (zIndex !== this.contentZIndex) this.contentZIndex = zIndex;
			});
			return () => {
				win.cancelAnimationFrame(rafId);
			};
		});
		user_effect(() => {
			this.floating.floating.current = this.wrapperRef.current;
		});
	}
};
var FloatingArrowState = class FloatingArrowState {
	static create(opts) {
		return new FloatingArrowState(opts, FloatingContentContext.get());
	}
	opts;
	content;
	constructor(opts, content) {
		this.opts = opts;
		this.content = content;
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		style: this.content.arrowStyle,
		"data-side": this.content.placedSide,
		...this.content.arrowAttachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
var FloatingAnchorState = class FloatingAnchorState {
	static create(opts, tooltip = false) {
		return tooltip ? new FloatingAnchorState(opts, FloatingTooltipRootContext.get()) : new FloatingAnchorState(opts, FloatingRootContext.get());
	}
	opts;
	root;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		if (opts.virtualEl && opts.virtualEl.current) root.triggerNode = boxFrom(opts.virtualEl.current);
		else root.triggerNode = opts.ref;
	}
};
function transformOrigin(options) {
	return {
		name: "transformOrigin",
		options,
		fn(data) {
			const { placement, rects, middlewareData } = data;
			const isArrowHidden = middlewareData.arrow?.centerOffset !== 0;
			const arrowWidth = isArrowHidden ? 0 : options.arrowWidth;
			const arrowHeight = isArrowHidden ? 0 : options.arrowHeight;
			const [placedSide, placedAlign] = getSideAndAlignFromPlacement(placement);
			const noArrowAlign = {
				start: "0%",
				center: "50%",
				end: "100%"
			}[placedAlign];
			const arrowXCenter = (middlewareData.arrow?.x ?? 0) + arrowWidth / 2;
			const arrowYCenter = (middlewareData.arrow?.y ?? 0) + arrowHeight / 2;
			let x = "";
			let y = "";
			if (placedSide === "bottom") {
				x = isArrowHidden ? noArrowAlign : `${arrowXCenter}px`;
				y = `${-arrowHeight}px`;
			} else if (placedSide === "top") {
				x = isArrowHidden ? noArrowAlign : `${arrowXCenter}px`;
				y = `${rects.floating.height + arrowHeight}px`;
			} else if (placedSide === "right") {
				x = `${-arrowHeight}px`;
				y = isArrowHidden ? noArrowAlign : `${arrowYCenter}px`;
			} else if (placedSide === "left") {
				x = `${rects.floating.width + arrowHeight}px`;
				y = isArrowHidden ? noArrowAlign : `${arrowYCenter}px`;
			}
			return { data: {
				x,
				y
			} };
		}
	};
}
function getSideAndAlignFromPlacement(placement) {
	const [side, align = "center"] = placement.split("-");
	return [side, align];
}
function getSideFromPlacement(placement) {
	return getSideAndAlignFromPlacement(placement)[0];
}
function getAlignFromPlacement(placement) {
	return getSideAndAlignFromPlacement(placement)[1];
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/floating-layer/components/floating-layer.svelte
function Floating_layer($$anchor, $$props) {
	push($$props, true);
	let tooltip = prop($$props, "tooltip", 3, false);
	FloatingRootState.create(tooltip());
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.children ?? noop$1);
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/arrow/arrow.svelte
var root_4$9 = from_svg(`<svg viewBox="0 0 30 10" preserveAspectRatio="none" data-arrow=""><polygon points="0,0 30,0 15,10" fill="currentColor"></polygon></svg>`);
var root_2$14 = from_html(`<span><!></span>`);
function Arrow($$anchor, $$props) {
	push($$props, true);
	let id = prop($$props, "id", 19, useId), width = prop($$props, "width", 3, 10), height = prop($$props, "height", 3, 5), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"children",
		"child",
		"width",
		"height"
	]);
	const mergedProps = user_derived(() => mergeProps(restProps, { id: id() }));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.child, () => ({ props: get$2(mergedProps) }));
		append($$anchor, fragment_1);
	};
	var alternate_1 = ($$anchor) => {
		var span = root_2$14();
		attribute_effect(span, () => ({ ...get$2(mergedProps) }));
		var node_2 = child(span);
		var consequent_1 = ($$anchor) => {
			var fragment_2 = comment();
			snippet(first_child(fragment_2), () => $$props.children ?? noop$1);
			append($$anchor, fragment_2);
		};
		var alternate = ($$anchor) => {
			var svg = root_4$9();
			template_effect(() => {
				set_attribute(svg, "width", width());
				set_attribute(svg, "height", height());
			});
			append($$anchor, svg);
		};
		if_block(node_2, ($$render) => {
			if ($$props.children) $$render(consequent_1);
			else $$render(alternate, -1);
		});
		reset(span);
		append($$anchor, span);
	};
	if_block(node, ($$render) => {
		if ($$props.child) $$render(consequent);
		else $$render(alternate_1, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/floating-layer/components/floating-layer-arrow.svelte
function Floating_layer_arrow($$anchor, $$props) {
	push($$props, true);
	let id = prop($$props, "id", 19, useId), ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"ref"
	]);
	const arrowState = FloatingArrowState.create({
		id: boxWith(() => id()),
		ref: boxWith(() => ref(), (v) => ref(v))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, arrowState.props));
	Arrow($$anchor, spread_props(() => get$2(mergedProps)));
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/floating-layer/components/floating-layer-content.svelte
function Floating_layer_content($$anchor, $$props) {
	push($$props, true);
	let side = prop($$props, "side", 3, "bottom"), sideOffset = prop($$props, "sideOffset", 3, 0), align = prop($$props, "align", 3, "center"), alignOffset = prop($$props, "alignOffset", 3, 0), arrowPadding = prop($$props, "arrowPadding", 3, 0), avoidCollisions = prop($$props, "avoidCollisions", 3, true), collisionBoundary = prop($$props, "collisionBoundary", 19, () => []), collisionPadding = prop($$props, "collisionPadding", 3, 0), hideWhenDetached = prop($$props, "hideWhenDetached", 3, false), onPlaced = prop($$props, "onPlaced", 3, () => {}), sticky = prop($$props, "sticky", 3, "partial"), updatePositionStrategy = prop($$props, "updatePositionStrategy", 3, "optimized"), strategy = prop($$props, "strategy", 3, "fixed"), dir = prop($$props, "dir", 3, "ltr"), style = prop($$props, "style", 19, () => ({})), wrapperId = prop($$props, "wrapperId", 19, useId), customAnchor = prop($$props, "customAnchor", 3, null), tooltip = prop($$props, "tooltip", 3, false);
	const contentState = FloatingContentState.create({
		side: boxWith(() => side()),
		sideOffset: boxWith(() => sideOffset()),
		align: boxWith(() => align()),
		alignOffset: boxWith(() => alignOffset()),
		id: boxWith(() => $$props.id),
		arrowPadding: boxWith(() => arrowPadding()),
		avoidCollisions: boxWith(() => avoidCollisions()),
		collisionBoundary: boxWith(() => collisionBoundary()),
		collisionPadding: boxWith(() => collisionPadding()),
		hideWhenDetached: boxWith(() => hideWhenDetached()),
		onPlaced: boxWith(() => onPlaced()),
		sticky: boxWith(() => sticky()),
		updatePositionStrategy: boxWith(() => updatePositionStrategy()),
		strategy: boxWith(() => strategy()),
		dir: boxWith(() => dir()),
		style: boxWith(() => style()),
		enabled: boxWith(() => $$props.enabled),
		wrapperId: boxWith(() => wrapperId()),
		customAnchor: boxWith(() => customAnchor())
	}, tooltip());
	const mergedProps = user_derived(() => mergeProps(contentState.wrapperProps, { style: { pointerEvents: "auto" } }));
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.content ?? noop$1, () => ({
		props: contentState.props,
		wrapperProps: get$2(mergedProps)
	}));
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/floating-layer/components/floating-layer-content-static.svelte
function Floating_layer_content_static($$anchor, $$props) {
	push($$props, true);
	onMount(() => {
		$$props.onPlaced?.();
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.content ?? noop$1, () => ({
		props: {},
		wrapperProps: {}
	}));
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/separator/separator.svelte.js
var separatorAttrs = createBitsAttrs({
	component: "separator",
	parts: ["root"]
});
var SeparatorRootState = class SeparatorRootState {
	static create(opts) {
		return new SeparatorRootState(opts);
	}
	opts;
	attachment;
	constructor(opts) {
		this.opts = opts;
		this.attachment = attachRef(opts.ref);
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		role: this.opts.decorative.current ? "none" : "separator",
		"aria-orientation": this.opts.orientation.current,
		"aria-hidden": boolToStrTrueOrUndef(this.opts.decorative.current),
		"data-orientation": this.opts.orientation.current,
		[separatorAttrs.root]: "",
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
//#endregion
//#region node_modules/bits-ui/dist/bits/separator/components/separator.svelte
var root_2$13 = from_html(`<div><!></div>`);
function Separator$1($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), ref = prop($$props, "ref", 15, null), decorative = prop($$props, "decorative", 3, false), orientation = prop($$props, "orientation", 3, "horizontal"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"ref",
		"child",
		"children",
		"decorative",
		"orientation"
	]);
	const rootState = SeparatorRootState.create({
		ref: boxWith(() => ref(), (v) => ref(v)),
		id: boxWith(() => id()),
		decorative: boxWith(() => decorative()),
		orientation: boxWith(() => orientation())
	});
	const mergedProps = user_derived(() => mergeProps(restProps, rootState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.child, () => ({ props: get$2(mergedProps) }));
		append($$anchor, fragment_1);
	};
	var alternate = ($$anchor) => {
		var div = root_2$13();
		attribute_effect(div, () => ({ ...get$2(mergedProps) }));
		snippet(child(div), () => $$props.children ?? noop$1);
		reset(div);
		append($$anchor, div);
	};
	if_block(node, ($$render) => {
		if ($$props.child) $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/popper-layer/popper-content.svelte
function Popper_content($$anchor, $$props) {
	let isStatic = prop($$props, "isStatic", 3, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"content",
		"isStatic",
		"onPlaced"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		Floating_layer_content_static($$anchor, {
			get content() {
				return $$props.content;
			},
			get onPlaced() {
				return $$props.onPlaced;
			}
		});
	};
	var alternate = ($$anchor) => {
		Floating_layer_content($$anchor, spread_props({
			get content() {
				return $$props.content;
			},
			get onPlaced() {
				return $$props.onPlaced;
			}
		}, () => restProps));
	};
	if_block(node, ($$render) => {
		if (isStatic()) $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/popper-layer/popper-layer-inner.svelte
var root_1$3 = from_html(`<!> <!>`, 1);
function Popper_layer_inner($$anchor, $$props) {
	push($$props, true);
	let interactOutsideBehavior = prop($$props, "interactOutsideBehavior", 3, "close"), trapFocus = prop($$props, "trapFocus", 3, true), isValidEvent = prop($$props, "isValidEvent", 3, () => false), customAnchor = prop($$props, "customAnchor", 3, null), isStatic = prop($$props, "isStatic", 3, false), tooltip = prop($$props, "tooltip", 3, false), contentPointerEvents = prop($$props, "contentPointerEvents", 3, "auto"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"popper",
		"onEscapeKeydown",
		"escapeKeydownBehavior",
		"preventOverflowTextSelection",
		"id",
		"onPointerDown",
		"onPointerUp",
		"side",
		"sideOffset",
		"align",
		"alignOffset",
		"arrowPadding",
		"avoidCollisions",
		"collisionBoundary",
		"collisionPadding",
		"sticky",
		"hideWhenDetached",
		"updatePositionStrategy",
		"strategy",
		"dir",
		"preventScroll",
		"wrapperId",
		"style",
		"onPlaced",
		"onInteractOutside",
		"onCloseAutoFocus",
		"onOpenAutoFocus",
		"onFocusOutside",
		"interactOutsideBehavior",
		"loop",
		"trapFocus",
		"isValidEvent",
		"customAnchor",
		"isStatic",
		"enabled",
		"ref",
		"tooltip",
		"contentPointerEvents"
	]);
	const resolvedPreventScroll = user_derived(() => $$props.preventScroll ?? true);
	const effectiveStrategy = user_derived(() => $$props.strategy ?? (get$2(resolvedPreventScroll) ? "fixed" : "absolute"));
	{
		const content = ($$anchor, $$arg0) => {
			let floatingProps = () => $$arg0?.().props;
			let wrapperProps = () => $$arg0?.().wrapperProps;
			var fragment_1 = root_1$3();
			var node = first_child(fragment_1);
			var consequent = ($$anchor) => {
				Scroll_lock($$anchor, { get preventScroll() {
					return get$2(resolvedPreventScroll);
				} });
			};
			var consequent_1 = ($$anchor) => {
				Scroll_lock($$anchor, { get preventScroll() {
					return get$2(resolvedPreventScroll);
				} });
			};
			if_block(node, ($$render) => {
				if ($$props.forceMount && $$props.enabled) $$render(consequent);
				else if (!$$props.forceMount) $$render(consequent_1, 1);
			});
			var node_1 = sibling(node, 2);
			{
				const focusScope = ($$anchor, $$arg0) => {
					let focusScopeProps = () => $$arg0?.().props;
					Escape_layer($$anchor, {
						get onEscapeKeydown() {
							return $$props.onEscapeKeydown;
						},
						get escapeKeydownBehavior() {
							return $$props.escapeKeydownBehavior;
						},
						get enabled() {
							return $$props.enabled;
						},
						get ref() {
							return $$props.ref;
						},
						children: ($$anchor, $$slotProps) => {
							{
								const children = ($$anchor, $$arg0) => {
									let dismissibleProps = () => $$arg0?.().props;
									Text_selection_layer($$anchor, {
										get id() {
											return $$props.id;
										},
										get preventOverflowTextSelection() {
											return $$props.preventOverflowTextSelection;
										},
										get onPointerDown() {
											return $$props.onPointerDown;
										},
										get onPointerUp() {
											return $$props.onPointerUp;
										},
										get enabled() {
											return $$props.enabled;
										},
										get ref() {
											return $$props.ref;
										},
										children: ($$anchor, $$slotProps) => {
											var fragment_7 = comment();
											var node_2 = first_child(fragment_7);
											{
												let $0 = user_derived(() => ({
													props: mergeProps(restProps, floatingProps(), dismissibleProps(), focusScopeProps(), { style: { pointerEvents: contentPointerEvents() } }),
													wrapperProps: wrapperProps()
												}));
												snippet(node_2, () => $$props.popper ?? noop$1, () => get$2($0));
											}
											append($$anchor, fragment_7);
										},
										$$slots: { default: true }
									});
								};
								Dismissible_layer($$anchor, {
									get id() {
										return $$props.id;
									},
									get onInteractOutside() {
										return $$props.onInteractOutside;
									},
									get onFocusOutside() {
										return $$props.onFocusOutside;
									},
									get interactOutsideBehavior() {
										return interactOutsideBehavior();
									},
									get isValidEvent() {
										return isValidEvent();
									},
									get enabled() {
										return $$props.enabled;
									},
									get ref() {
										return $$props.ref;
									},
									children,
									$$slots: { default: true }
								});
							}
						},
						$$slots: { default: true }
					});
				};
				Focus_scope(node_1, {
					get onOpenAutoFocus() {
						return $$props.onOpenAutoFocus;
					},
					get onCloseAutoFocus() {
						return $$props.onCloseAutoFocus;
					},
					get loop() {
						return $$props.loop;
					},
					get enabled() {
						return $$props.enabled;
					},
					get trapFocus() {
						return trapFocus();
					},
					get forceMount() {
						return $$props.forceMount;
					},
					get ref() {
						return $$props.ref;
					},
					focusScope,
					$$slots: { focusScope: true }
				});
			}
			append($$anchor, fragment_1);
		};
		Popper_content($$anchor, {
			get isStatic() {
				return isStatic();
			},
			get id() {
				return $$props.id;
			},
			get side() {
				return $$props.side;
			},
			get sideOffset() {
				return $$props.sideOffset;
			},
			get align() {
				return $$props.align;
			},
			get alignOffset() {
				return $$props.alignOffset;
			},
			get arrowPadding() {
				return $$props.arrowPadding;
			},
			get avoidCollisions() {
				return $$props.avoidCollisions;
			},
			get collisionBoundary() {
				return $$props.collisionBoundary;
			},
			get collisionPadding() {
				return $$props.collisionPadding;
			},
			get sticky() {
				return $$props.sticky;
			},
			get hideWhenDetached() {
				return $$props.hideWhenDetached;
			},
			get updatePositionStrategy() {
				return $$props.updatePositionStrategy;
			},
			get strategy() {
				return get$2(effectiveStrategy);
			},
			get dir() {
				return $$props.dir;
			},
			get wrapperId() {
				return $$props.wrapperId;
			},
			get style() {
				return $$props.style;
			},
			get onPlaced() {
				return $$props.onPlaced;
			},
			get customAnchor() {
				return customAnchor();
			},
			get enabled() {
				return $$props.enabled;
			},
			get tooltip() {
				return tooltip();
			},
			content,
			$$slots: { content: true }
		});
	}
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/popper-layer/popper-layer.svelte
function Popper_layer($$anchor, $$props) {
	let interactOutsideBehavior = prop($$props, "interactOutsideBehavior", 3, "close"), trapFocus = prop($$props, "trapFocus", 3, true), isValidEvent = prop($$props, "isValidEvent", 3, () => false), customAnchor = prop($$props, "customAnchor", 3, null), isStatic = prop($$props, "isStatic", 3, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"popper",
		"open",
		"onEscapeKeydown",
		"escapeKeydownBehavior",
		"preventOverflowTextSelection",
		"id",
		"onPointerDown",
		"onPointerUp",
		"side",
		"sideOffset",
		"align",
		"alignOffset",
		"arrowPadding",
		"avoidCollisions",
		"collisionBoundary",
		"collisionPadding",
		"sticky",
		"hideWhenDetached",
		"updatePositionStrategy",
		"strategy",
		"dir",
		"preventScroll",
		"wrapperId",
		"style",
		"onPlaced",
		"onInteractOutside",
		"onCloseAutoFocus",
		"onOpenAutoFocus",
		"onFocusOutside",
		"interactOutsideBehavior",
		"loop",
		"trapFocus",
		"isValidEvent",
		"customAnchor",
		"isStatic",
		"ref",
		"shouldRender"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		Popper_layer_inner($$anchor, spread_props({
			get popper() {
				return $$props.popper;
			},
			get onEscapeKeydown() {
				return $$props.onEscapeKeydown;
			},
			get escapeKeydownBehavior() {
				return $$props.escapeKeydownBehavior;
			},
			get preventOverflowTextSelection() {
				return $$props.preventOverflowTextSelection;
			},
			get id() {
				return $$props.id;
			},
			get onPointerDown() {
				return $$props.onPointerDown;
			},
			get onPointerUp() {
				return $$props.onPointerUp;
			},
			get side() {
				return $$props.side;
			},
			get sideOffset() {
				return $$props.sideOffset;
			},
			get align() {
				return $$props.align;
			},
			get alignOffset() {
				return $$props.alignOffset;
			},
			get arrowPadding() {
				return $$props.arrowPadding;
			},
			get avoidCollisions() {
				return $$props.avoidCollisions;
			},
			get collisionBoundary() {
				return $$props.collisionBoundary;
			},
			get collisionPadding() {
				return $$props.collisionPadding;
			},
			get sticky() {
				return $$props.sticky;
			},
			get hideWhenDetached() {
				return $$props.hideWhenDetached;
			},
			get updatePositionStrategy() {
				return $$props.updatePositionStrategy;
			},
			get strategy() {
				return $$props.strategy;
			},
			get dir() {
				return $$props.dir;
			},
			get preventScroll() {
				return $$props.preventScroll;
			},
			get wrapperId() {
				return $$props.wrapperId;
			},
			get style() {
				return $$props.style;
			},
			get onPlaced() {
				return $$props.onPlaced;
			},
			get customAnchor() {
				return customAnchor();
			},
			get isStatic() {
				return isStatic();
			},
			get enabled() {
				return $$props.open;
			},
			get onInteractOutside() {
				return $$props.onInteractOutside;
			},
			get onCloseAutoFocus() {
				return $$props.onCloseAutoFocus;
			},
			get onOpenAutoFocus() {
				return $$props.onOpenAutoFocus;
			},
			get interactOutsideBehavior() {
				return interactOutsideBehavior();
			},
			get loop() {
				return $$props.loop;
			},
			get trapFocus() {
				return trapFocus();
			},
			get isValidEvent() {
				return isValidEvent();
			},
			get onFocusOutside() {
				return $$props.onFocusOutside;
			},
			forceMount: false,
			get ref() {
				return $$props.ref;
			}
		}, () => restProps));
	};
	if_block(node, ($$render) => {
		if ($$props.shouldRender) $$render(consequent);
	});
	append($$anchor, fragment);
}
//#endregion
//#region node_modules/bits-ui/dist/bits/utilities/popper-layer/popper-layer-force-mount.svelte
function Popper_layer_force_mount($$anchor, $$props) {
	let interactOutsideBehavior = prop($$props, "interactOutsideBehavior", 3, "close"), trapFocus = prop($$props, "trapFocus", 3, true), isValidEvent = prop($$props, "isValidEvent", 3, () => false), customAnchor = prop($$props, "customAnchor", 3, null), isStatic = prop($$props, "isStatic", 3, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"popper",
		"onEscapeKeydown",
		"escapeKeydownBehavior",
		"preventOverflowTextSelection",
		"id",
		"onPointerDown",
		"onPointerUp",
		"side",
		"sideOffset",
		"align",
		"alignOffset",
		"arrowPadding",
		"avoidCollisions",
		"collisionBoundary",
		"collisionPadding",
		"sticky",
		"hideWhenDetached",
		"updatePositionStrategy",
		"strategy",
		"dir",
		"preventScroll",
		"wrapperId",
		"style",
		"onPlaced",
		"onInteractOutside",
		"onCloseAutoFocus",
		"onOpenAutoFocus",
		"onFocusOutside",
		"interactOutsideBehavior",
		"loop",
		"trapFocus",
		"isValidEvent",
		"customAnchor",
		"isStatic",
		"enabled"
	]);
	Popper_layer_inner($$anchor, spread_props({
		get popper() {
			return $$props.popper;
		},
		get onEscapeKeydown() {
			return $$props.onEscapeKeydown;
		},
		get escapeKeydownBehavior() {
			return $$props.escapeKeydownBehavior;
		},
		get preventOverflowTextSelection() {
			return $$props.preventOverflowTextSelection;
		},
		get id() {
			return $$props.id;
		},
		get onPointerDown() {
			return $$props.onPointerDown;
		},
		get onPointerUp() {
			return $$props.onPointerUp;
		},
		get side() {
			return $$props.side;
		},
		get sideOffset() {
			return $$props.sideOffset;
		},
		get align() {
			return $$props.align;
		},
		get alignOffset() {
			return $$props.alignOffset;
		},
		get arrowPadding() {
			return $$props.arrowPadding;
		},
		get avoidCollisions() {
			return $$props.avoidCollisions;
		},
		get collisionBoundary() {
			return $$props.collisionBoundary;
		},
		get collisionPadding() {
			return $$props.collisionPadding;
		},
		get sticky() {
			return $$props.sticky;
		},
		get hideWhenDetached() {
			return $$props.hideWhenDetached;
		},
		get updatePositionStrategy() {
			return $$props.updatePositionStrategy;
		},
		get strategy() {
			return $$props.strategy;
		},
		get dir() {
			return $$props.dir;
		},
		get preventScroll() {
			return $$props.preventScroll;
		},
		get wrapperId() {
			return $$props.wrapperId;
		},
		get style() {
			return $$props.style;
		},
		get onPlaced() {
			return $$props.onPlaced;
		},
		get customAnchor() {
			return customAnchor();
		},
		get isStatic() {
			return isStatic();
		},
		get enabled() {
			return $$props.enabled;
		},
		get onInteractOutside() {
			return $$props.onInteractOutside;
		},
		get onCloseAutoFocus() {
			return $$props.onCloseAutoFocus;
		},
		get onOpenAutoFocus() {
			return $$props.onOpenAutoFocus;
		},
		get interactOutsideBehavior() {
			return interactOutsideBehavior();
		},
		get loop() {
			return $$props.loop;
		},
		get trapFocus() {
			return trapFocus();
		},
		get isValidEvent() {
			return isValidEvent();
		},
		get onFocusOutside() {
			return $$props.onFocusOutside;
		}
	}, () => restProps, { forceMount: true }));
}
//#endregion
//#region node_modules/bits-ui/dist/internal/safe-polygon.svelte.js
function isPointInPolygon(point, polygon) {
	const [x, y] = point;
	let isInside = false;
	const length = polygon.length;
	for (let i = 0, j = length - 1; i < length; j = i++) {
		const [xi, yi] = polygon[i] ?? [0, 0];
		const [xj, yj] = polygon[j] ?? [0, 0];
		if (yi >= y !== yj >= y && x <= (xj - xi) * (y - yi) / (yj - yi) + xi) isInside = !isInside;
	}
	return isInside;
}
function isInsideRect(point, rect) {
	return point[0] >= rect.left && point[0] <= rect.right && point[1] >= rect.top && point[1] <= rect.bottom;
}
function getSide(triggerRect, contentRect) {
	const triggerCenterX = triggerRect.left + triggerRect.width / 2;
	const triggerCenterY = triggerRect.top + triggerRect.height / 2;
	const contentCenterX = contentRect.left + contentRect.width / 2;
	const contentCenterY = contentRect.top + contentRect.height / 2;
	const deltaX = contentCenterX - triggerCenterX;
	const deltaY = contentCenterY - triggerCenterY;
	if (Math.abs(deltaX) > Math.abs(deltaY)) return deltaX > 0 ? "right" : "left";
	return deltaY > 0 ? "bottom" : "top";
}
/**
* Creates a safe polygon area that allows users to move their cursor between
* the trigger and floating content without closing it.
*/
var SafePolygon = class {
	#opts;
	#buffer;
	#transitIntentTimeout;
	#exitPoint = null;
	#exitTarget = null;
	#transitTargets = [];
	#trackedTriggerNode = null;
	#leaveFallbackRafId = null;
	#transitIntentTimeoutId = null;
	#cancelLeaveFallback() {
		if (this.#leaveFallbackRafId !== null) {
			cancelAnimationFrame(this.#leaveFallbackRafId);
			this.#leaveFallbackRafId = null;
		}
	}
	#scheduleLeaveFallback() {
		this.#cancelLeaveFallback();
		this.#leaveFallbackRafId = requestAnimationFrame(() => {
			this.#leaveFallbackRafId = null;
			if (!this.#exitPoint || !this.#exitTarget) return;
			this.#clearTracking();
			this.#opts.onPointerExit();
		});
	}
	#cancelTransitIntentTimeout() {
		if (this.#transitIntentTimeoutId !== null) {
			clearTimeout(this.#transitIntentTimeoutId);
			this.#transitIntentTimeoutId = null;
		}
	}
	#scheduleTransitIntentTimeout() {
		if (this.#transitIntentTimeout === null) return;
		this.#cancelTransitIntentTimeout();
		this.#transitIntentTimeoutId = window.setTimeout(() => {
			this.#transitIntentTimeoutId = null;
			if (!this.#exitPoint || !this.#exitTarget) return;
			this.#clearTracking();
			this.#opts.onPointerExit();
		}, this.#transitIntentTimeout);
	}
	constructor(opts) {
		this.#opts = opts;
		this.#buffer = opts.buffer ?? 1;
		const transitIntentTimeout = opts.transitIntentTimeout;
		this.#transitIntentTimeout = typeof transitIntentTimeout === "number" && transitIntentTimeout > 0 ? transitIntentTimeout : null;
		watch$1([
			opts.triggerNode,
			opts.contentNode,
			opts.enabled
		], ([triggerNode, contentNode, enabled]) => {
			if (!triggerNode || !contentNode || !enabled) {
				this.#trackedTriggerNode = null;
				this.#clearTracking();
				return;
			}
			if (this.#trackedTriggerNode && this.#trackedTriggerNode !== triggerNode) this.#clearTracking();
			this.#trackedTriggerNode = triggerNode;
			const doc = getDocument(triggerNode);
			const handlePointerMove = (e) => {
				this.#onPointerMove([e.clientX, e.clientY], triggerNode, contentNode);
			};
			const handleTriggerLeave = (e) => {
				const target = e.relatedTarget;
				if (isElement$1(target) && contentNode.contains(target)) return;
				const ignoredTargets = this.#opts.ignoredTargets?.() ?? [];
				if (isElement$1(target) && ignoredTargets.some((n) => n === target || n.contains(target))) return;
				this.#transitTargets = isElement$1(target) && ignoredTargets.length > 0 ? ignoredTargets.filter((n) => target.contains(n)) : [];
				this.#exitPoint = [e.clientX, e.clientY];
				this.#exitTarget = "content";
				this.#scheduleLeaveFallback();
			};
			const handleTriggerEnter = () => {
				this.#clearTracking();
			};
			const handleContentEnter = () => {
				this.#clearTracking();
			};
			const handleContentLeave = (e) => {
				const target = e.relatedTarget;
				if (isElement$1(target) && triggerNode.contains(target)) return;
				this.#exitPoint = [e.clientX, e.clientY];
				this.#exitTarget = "trigger";
				this.#scheduleLeaveFallback();
			};
			return [
				on(doc, "pointermove", handlePointerMove),
				on(triggerNode, "pointerleave", handleTriggerLeave),
				on(triggerNode, "pointerenter", handleTriggerEnter),
				on(contentNode, "pointerenter", handleContentEnter),
				on(contentNode, "pointerleave", handleContentLeave)
			].reduce((acc, cleanup) => () => {
				acc();
				cleanup();
			}, () => {});
		});
	}
	#onPointerMove(clientPoint, triggerNode, contentNode) {
		if (!this.#exitPoint || !this.#exitTarget) return;
		this.#cancelLeaveFallback();
		this.#scheduleTransitIntentTimeout();
		const triggerRect = triggerNode.getBoundingClientRect();
		const contentRect = contentNode.getBoundingClientRect();
		if (this.#exitTarget === "content" && isInsideRect(clientPoint, contentRect)) {
			this.#clearTracking();
			return;
		}
		if (this.#exitTarget === "trigger" && isInsideRect(clientPoint, triggerRect)) {
			this.#clearTracking();
			return;
		}
		if (this.#exitTarget === "content" && this.#transitTargets.length > 0) for (const transitTarget of this.#transitTargets) {
			const transitRect = transitTarget.getBoundingClientRect();
			if (isInsideRect(clientPoint, transitRect)) return;
			const transitSide = getSide(triggerRect, transitRect);
			const transitCorridor = this.#getCorridorPolygon(triggerRect, transitRect, transitSide);
			if (transitCorridor && isPointInPolygon(clientPoint, transitCorridor)) return;
		}
		const side = getSide(triggerRect, contentRect);
		const corridorPoly = this.#getCorridorPolygon(triggerRect, contentRect, side);
		if (corridorPoly && isPointInPolygon(clientPoint, corridorPoly)) return;
		const targetRect = this.#exitTarget === "content" ? contentRect : triggerRect;
		if (isPointInPolygon(clientPoint, this.#getSafePolygon(this.#exitPoint, targetRect, side, this.#exitTarget))) return;
		this.#clearTracking();
		this.#opts.onPointerExit();
	}
	#clearTracking() {
		this.#exitPoint = null;
		this.#exitTarget = null;
		this.#transitTargets = [];
		this.#cancelLeaveFallback();
		this.#cancelTransitIntentTimeout();
	}
	/**
	* Creates a rectangular corridor between trigger and content
	* This prevents closing when cursor is in the gap between them
	*/
	#getCorridorPolygon(triggerRect, contentRect, side) {
		const buffer = this.#buffer;
		switch (side) {
			case "top": return [
				[Math.min(triggerRect.left, contentRect.left) - buffer, triggerRect.top],
				[Math.min(triggerRect.left, contentRect.left) - buffer, contentRect.bottom],
				[Math.max(triggerRect.right, contentRect.right) + buffer, contentRect.bottom],
				[Math.max(triggerRect.right, contentRect.right) + buffer, triggerRect.top]
			];
			case "bottom": return [
				[Math.min(triggerRect.left, contentRect.left) - buffer, triggerRect.bottom],
				[Math.min(triggerRect.left, contentRect.left) - buffer, contentRect.top],
				[Math.max(triggerRect.right, contentRect.right) + buffer, contentRect.top],
				[Math.max(triggerRect.right, contentRect.right) + buffer, triggerRect.bottom]
			];
			case "left": return [
				[triggerRect.left, Math.min(triggerRect.top, contentRect.top) - buffer],
				[contentRect.right, Math.min(triggerRect.top, contentRect.top) - buffer],
				[contentRect.right, Math.max(triggerRect.bottom, contentRect.bottom) + buffer],
				[triggerRect.left, Math.max(triggerRect.bottom, contentRect.bottom) + buffer]
			];
			case "right": return [
				[triggerRect.right, Math.min(triggerRect.top, contentRect.top) - buffer],
				[contentRect.left, Math.min(triggerRect.top, contentRect.top) - buffer],
				[contentRect.left, Math.max(triggerRect.bottom, contentRect.bottom) + buffer],
				[triggerRect.right, Math.max(triggerRect.bottom, contentRect.bottom) + buffer]
			];
		}
	}
	/**
	* Creates a triangular/trapezoidal safe zone from the exit point to the target
	*/
	#getSafePolygon(exitPoint, targetRect, side, exitTarget) {
		const buffer = this.#buffer * 4;
		const [x, y] = exitPoint;
		switch (exitTarget === "trigger" ? this.#flipSide(side) : side) {
			case "top": return [
				[x - buffer, y + buffer],
				[x + buffer, y + buffer],
				[targetRect.right + buffer, targetRect.bottom],
				[targetRect.right + buffer, targetRect.top],
				[targetRect.left - buffer, targetRect.top],
				[targetRect.left - buffer, targetRect.bottom]
			];
			case "bottom": return [
				[x - buffer, y - buffer],
				[x + buffer, y - buffer],
				[targetRect.right + buffer, targetRect.top],
				[targetRect.right + buffer, targetRect.bottom],
				[targetRect.left - buffer, targetRect.bottom],
				[targetRect.left - buffer, targetRect.top]
			];
			case "left": return [
				[x + buffer, y - buffer],
				[x + buffer, y + buffer],
				[targetRect.right, targetRect.bottom + buffer],
				[targetRect.left, targetRect.bottom + buffer],
				[targetRect.left, targetRect.top - buffer],
				[targetRect.right, targetRect.top - buffer]
			];
			case "right": return [
				[x - buffer, y - buffer],
				[x - buffer, y + buffer],
				[targetRect.left, targetRect.bottom + buffer],
				[targetRect.right, targetRect.bottom + buffer],
				[targetRect.right, targetRect.top - buffer],
				[targetRect.left, targetRect.top - buffer]
			];
		}
	}
	#flipSide(side) {
		switch (side) {
			case "top": return "bottom";
			case "bottom": return "top";
			case "left": return "right";
			case "right": return "left";
		}
	}
};
//#endregion
//#region node_modules/bits-ui/dist/internal/timeout-fn.js
var TimeoutFn = class {
	#interval;
	#cb;
	#timer = null;
	constructor(cb, interval) {
		this.#cb = cb;
		this.#interval = interval;
		this.stop = this.stop.bind(this);
		this.start = this.start.bind(this);
		onDestroyEffect(this.stop);
	}
	#clear() {
		if (this.#timer !== null) {
			window.clearTimeout(this.#timer);
			this.#timer = null;
		}
	}
	stop() {
		this.#clear();
	}
	start(...args) {
		this.#clear();
		this.#timer = window.setTimeout(() => {
			this.#timer = null;
			this.#cb(...args);
		}, this.#interval);
	}
};
//#endregion
//#region node_modules/bits-ui/dist/bits/tooltip/tooltip.svelte.js
var tooltipAttrs = createBitsAttrs({
	component: "tooltip",
	parts: ["content", "trigger"]
});
var TooltipProviderContext = new Context$1("Tooltip.Provider");
var TooltipRootContext = new Context$1("Tooltip.Root");
var TooltipTriggerRegistryState = class {
	#triggers = state$1(proxy(/* @__PURE__ */ new Map()));
	get triggers() {
		return get$2(this.#triggers);
	}
	set triggers(value) {
		set(this.#triggers, value, true);
	}
	#activeTriggerId = state$1(null);
	get activeTriggerId() {
		return get$2(this.#activeTriggerId);
	}
	set activeTriggerId(value) {
		set(this.#activeTriggerId, value, true);
	}
	#activeTriggerNode = user_derived(() => {
		const activeTriggerId = this.activeTriggerId;
		if (activeTriggerId === null) return null;
		return this.triggers.get(activeTriggerId)?.node ?? null;
	});
	get activeTriggerNode() {
		return get$2(this.#activeTriggerNode);
	}
	set activeTriggerNode(value) {
		set(this.#activeTriggerNode, value);
	}
	#activePayload = user_derived(() => {
		const activeTriggerId = this.activeTriggerId;
		if (activeTriggerId === null) return null;
		return this.triggers.get(activeTriggerId)?.payload ?? null;
	});
	get activePayload() {
		return get$2(this.#activePayload);
	}
	set activePayload(value) {
		set(this.#activePayload, value);
	}
	register = (record) => {
		const next = new Map(this.triggers);
		next.set(record.id, record);
		this.triggers = next;
		this.#coerceActiveTrigger();
	};
	update = (record) => {
		const next = new Map(this.triggers);
		next.set(record.id, record);
		this.triggers = next;
		this.#coerceActiveTrigger();
	};
	unregister = (id) => {
		if (!this.triggers.has(id)) return;
		const next = new Map(this.triggers);
		next.delete(id);
		this.triggers = next;
		if (this.activeTriggerId === id) this.activeTriggerId = null;
	};
	setActiveTrigger = (id) => {
		if (id === null) {
			this.activeTriggerId = null;
			return;
		}
		if (!this.triggers.has(id)) {
			this.activeTriggerId = null;
			return;
		}
		this.activeTriggerId = id;
	};
	get = (id) => {
		return this.triggers.get(id);
	};
	has = (id) => {
		return this.triggers.has(id);
	};
	getFirstTriggerId = () => {
		const firstEntry = this.triggers.entries().next();
		if (firstEntry.done) return null;
		return firstEntry.value[0];
	};
	#coerceActiveTrigger = () => {
		const activeTriggerId = this.activeTriggerId;
		if (activeTriggerId === null) return;
		if (!this.triggers.has(activeTriggerId)) this.activeTriggerId = null;
	};
};
var TooltipProviderState = class TooltipProviderState {
	static create(opts) {
		return TooltipProviderContext.set(new TooltipProviderState(opts));
	}
	opts;
	#isOpenDelayed = state$1(true);
	get isOpenDelayed() {
		return get$2(this.#isOpenDelayed);
	}
	set isOpenDelayed(value) {
		set(this.#isOpenDelayed, value, true);
	}
	isPointerInTransit = simpleBox(false);
	#timerFn;
	#openTooltip = state$1(null);
	constructor(opts) {
		this.opts = opts;
		this.#timerFn = new TimeoutFn(() => {
			this.isOpenDelayed = true;
		}, this.opts.skipDelayDuration.current);
		onMountEffect(() => on(window, "scroll", (e) => {
			const activeTooltip = get$2(this.#openTooltip);
			if (!activeTooltip) return;
			const triggerNode = activeTooltip.triggerNode;
			if (!triggerNode) return;
			const target = e.target;
			if (!(target instanceof Element || target instanceof Document)) return;
			if (target.contains(triggerNode)) activeTooltip.handleClose();
		}));
	}
	#startTimer = () => {
		if (this.opts.skipDelayDuration.current === 0) {
			this.isOpenDelayed = true;
			return;
		} else this.#timerFn.start();
	};
	#clearTimer = () => {
		this.#timerFn.stop();
	};
	onOpen = (tooltip) => {
		if (get$2(this.#openTooltip) && get$2(this.#openTooltip) !== tooltip) get$2(this.#openTooltip).handleClose();
		this.#clearTimer();
		this.isOpenDelayed = false;
		set(this.#openTooltip, tooltip, true);
	};
	onClose = (tooltip) => {
		if (get$2(this.#openTooltip) === tooltip) {
			set(this.#openTooltip, null);
			this.#startTimer();
		}
	};
	isTooltipOpen = (tooltip) => {
		return get$2(this.#openTooltip) === tooltip;
	};
};
var TooltipRootState = class TooltipRootState {
	static create(opts) {
		return TooltipRootContext.set(new TooltipRootState(opts, TooltipProviderContext.get()));
	}
	opts;
	provider;
	#delayDuration = user_derived(() => this.opts.delayDuration.current ?? this.provider.opts.delayDuration.current);
	get delayDuration() {
		return get$2(this.#delayDuration);
	}
	set delayDuration(value) {
		set(this.#delayDuration, value);
	}
	#disableHoverableContent = user_derived(() => this.opts.disableHoverableContent.current ?? this.provider.opts.disableHoverableContent.current);
	get disableHoverableContent() {
		return get$2(this.#disableHoverableContent);
	}
	set disableHoverableContent(value) {
		set(this.#disableHoverableContent, value);
	}
	#disableCloseOnTriggerClick = user_derived(() => this.opts.disableCloseOnTriggerClick.current ?? this.provider.opts.disableCloseOnTriggerClick.current);
	get disableCloseOnTriggerClick() {
		return get$2(this.#disableCloseOnTriggerClick);
	}
	set disableCloseOnTriggerClick(value) {
		set(this.#disableCloseOnTriggerClick, value);
	}
	#disabled = user_derived(() => this.opts.disabled.current ?? this.provider.opts.disabled.current);
	get disabled() {
		return get$2(this.#disabled);
	}
	set disabled(value) {
		set(this.#disabled, value);
	}
	#ignoreNonKeyboardFocus = user_derived(() => this.opts.ignoreNonKeyboardFocus.current ?? this.provider.opts.ignoreNonKeyboardFocus.current);
	get ignoreNonKeyboardFocus() {
		return get$2(this.#ignoreNonKeyboardFocus);
	}
	set ignoreNonKeyboardFocus(value) {
		set(this.#ignoreNonKeyboardFocus, value);
	}
	registry;
	tether;
	#contentNode = state$1(null);
	get contentNode() {
		return get$2(this.#contentNode);
	}
	set contentNode(value) {
		set(this.#contentNode, value, true);
	}
	contentPresence;
	#wasOpenDelayed = state$1(false);
	#timerFn;
	#stateAttr = user_derived(() => {
		if (!this.opts.open.current) return "closed";
		return get$2(this.#wasOpenDelayed) ? "delayed-open" : "instant-open";
	});
	get stateAttr() {
		return get$2(this.#stateAttr);
	}
	set stateAttr(value) {
		set(this.#stateAttr, value);
	}
	constructor(opts, provider) {
		this.opts = opts;
		this.provider = provider;
		this.tether = opts.tether.current?.state ?? null;
		this.registry = this.tether?.registry ?? new TooltipTriggerRegistryState();
		this.#timerFn = new TimeoutFn(() => {
			set(this.#wasOpenDelayed, true);
			this.opts.open.current = true;
		}, this.delayDuration ?? 0);
		if (this.tether) {
			this.tether.root = this;
			onMountEffect(() => {
				return () => {
					if (this.tether?.root === this) this.tether.root = null;
				};
			});
		}
		this.contentPresence = new PresenceManager({
			open: this.opts.open,
			ref: boxWith(() => this.contentNode),
			onComplete: () => {
				this.opts.onOpenChangeComplete.current(this.opts.open.current);
			}
		});
		watch$1(() => this.delayDuration, () => {
			if (this.delayDuration === void 0) return;
			this.#timerFn = new TimeoutFn(() => {
				set(this.#wasOpenDelayed, true);
				this.opts.open.current = true;
			}, this.delayDuration);
		});
		watch$1(() => this.opts.open.current, (isOpen) => {
			if (isOpen) {
				this.ensureActiveTrigger();
				this.provider.onOpen(this);
			} else this.provider.onClose(this);
		}, { lazy: true });
		watch$1(() => this.opts.triggerId.current, (triggerId) => {
			if (triggerId === this.registry.activeTriggerId) return;
			this.registry.setActiveTrigger(triggerId);
		});
		watch$1(() => this.registry.activeTriggerId, (activeTriggerId) => {
			if (this.opts.triggerId.current === activeTriggerId) return;
			this.opts.triggerId.current = activeTriggerId;
		});
	}
	handleOpen = () => {
		this.#timerFn.stop();
		set(this.#wasOpenDelayed, false);
		this.ensureActiveTrigger();
		this.opts.open.current = true;
	};
	handleClose = () => {
		this.#timerFn.stop();
		this.opts.open.current = false;
	};
	#handleDelayedOpen = () => {
		this.#timerFn.stop();
		const shouldSkipDelay = !this.provider.isOpenDelayed;
		const delayDuration = this.delayDuration ?? 0;
		if (shouldSkipDelay || delayDuration === 0) {
			set(this.#wasOpenDelayed, false);
			this.opts.open.current = true;
		} else this.#timerFn.start();
	};
	onTriggerEnter = (triggerId) => {
		this.setActiveTrigger(triggerId);
		this.#handleDelayedOpen();
	};
	onTriggerLeave = () => {
		if (this.disableHoverableContent) this.handleClose();
		else this.#timerFn.stop();
	};
	ensureActiveTrigger = () => {
		if (this.registry.activeTriggerId !== null && this.registry.has(this.registry.activeTriggerId)) return;
		if (this.opts.triggerId.current !== null && this.registry.has(this.opts.triggerId.current)) {
			this.registry.setActiveTrigger(this.opts.triggerId.current);
			return;
		}
		const firstTriggerId = this.registry.getFirstTriggerId();
		this.registry.setActiveTrigger(firstTriggerId);
	};
	setActiveTrigger = (triggerId) => {
		this.registry.setActiveTrigger(triggerId);
	};
	registerTrigger = (trigger) => {
		this.registry.register(trigger);
		if (trigger.disabled && this.registry.activeTriggerId === trigger.id && this.opts.open.current) this.handleClose();
	};
	updateTrigger = (trigger) => {
		this.registry.update(trigger);
		if (trigger.disabled && this.registry.activeTriggerId === trigger.id && this.opts.open.current) this.handleClose();
	};
	unregisterTrigger = (id) => {
		const isActive = this.registry.activeTriggerId === id;
		this.registry.unregister(id);
		if (isActive && this.opts.open.current) this.handleClose();
	};
	isActiveTrigger = (triggerId) => {
		return this.registry.activeTriggerId === triggerId;
	};
	get triggerNode() {
		return this.registry.activeTriggerNode;
	}
	get activePayload() {
		return this.registry.activePayload;
	}
	get activeTriggerId() {
		return this.registry.activeTriggerId;
	}
};
var TooltipTriggerState = class TooltipTriggerState {
	static create(opts) {
		if (opts.tether.current) return new TooltipTriggerState(opts, null, opts.tether.current.state);
		return new TooltipTriggerState(opts, TooltipRootContext.get(), null);
	}
	opts;
	root;
	tether;
	attachment;
	#isPointerDown = simpleBox(false);
	#hasPointerMoveOpened = state$1(false);
	domContext;
	#transitCheckTimeout = null;
	#mounted = false;
	#lastRegisteredId = null;
	constructor(opts, root, tether) {
		this.opts = opts;
		this.root = root;
		this.tether = tether;
		this.domContext = new DOMContext(opts.ref);
		this.attachment = attachRef(this.opts.ref, (v) => this.#register(v));
		watch$1(() => this.opts.id.current, () => {
			this.#register(this.opts.ref.current);
		});
		watch$1(() => this.opts.payload.current, () => {
			this.#register(this.opts.ref.current);
		});
		watch$1(() => this.opts.disabled.current, () => {
			this.#register(this.opts.ref.current);
		});
		onMountEffect(() => {
			this.#mounted = true;
			this.#register(this.opts.ref.current);
			return () => {
				const root = this.#getRoot();
				const id = this.#lastRegisteredId;
				if (id) if (this.tether) this.tether.registry.unregister(id);
				else root?.unregisterTrigger(id);
				this.#lastRegisteredId = null;
				this.#mounted = false;
			};
		});
	}
	#getRoot = () => {
		return this.tether?.root ?? this.root;
	};
	#isDisabled = () => {
		const root = this.#getRoot();
		return this.opts.disabled.current || Boolean(root?.disabled);
	};
	#register = (node) => {
		if (!this.#mounted) return;
		const id = this.opts.id.current;
		const payload = this.opts.payload.current;
		const disabled = this.opts.disabled.current;
		if (this.#lastRegisteredId && this.#lastRegisteredId !== id) {
			const root = this.#getRoot();
			if (this.tether) this.tether.registry.unregister(this.#lastRegisteredId);
			else root?.unregisterTrigger(this.#lastRegisteredId);
		}
		const triggerRecord = {
			id,
			node,
			payload,
			disabled
		};
		const root = this.#getRoot();
		if (this.tether) {
			if (this.tether.registry.has(id)) this.tether.registry.update(triggerRecord);
			else this.tether.registry.register(triggerRecord);
			if (disabled && this.tether.registry.activeTriggerId === id && root?.opts.open.current) root.handleClose();
		} else if (root?.registry.has(id)) root.updateTrigger(triggerRecord);
		else root?.registerTrigger(triggerRecord);
		this.#lastRegisteredId = id;
	};
	#clearTransitCheck = () => {
		if (this.#transitCheckTimeout !== null) {
			clearTimeout(this.#transitCheckTimeout);
			this.#transitCheckTimeout = null;
		}
	};
	handlePointerUp = () => {
		this.#isPointerDown.current = false;
	};
	#onpointerup = () => {
		if (this.#isDisabled()) return;
		this.#isPointerDown.current = false;
	};
	#onpointerdown = () => {
		if (this.#isDisabled()) return;
		this.#isPointerDown.current = true;
		this.domContext.getDocument().addEventListener("pointerup", () => {
			this.handlePointerUp();
		}, { once: true });
	};
	#onpointerenter = (e) => {
		const root = this.#getRoot();
		if (!root) return;
		if (this.#isDisabled()) {
			if (root.opts.open.current) root.handleClose();
			return;
		}
		if (e.pointerType === "touch") return;
		if (root.provider.isPointerInTransit.current) {
			this.#clearTransitCheck();
			this.#transitCheckTimeout = window.setTimeout(() => {
				if (root.provider.isPointerInTransit.current) {
					root.provider.isPointerInTransit.current = false;
					root.onTriggerEnter(this.opts.id.current);
					set(this.#hasPointerMoveOpened, true);
				}
			}, 250);
			return;
		}
		root.onTriggerEnter(this.opts.id.current);
		set(this.#hasPointerMoveOpened, true);
	};
	#onpointermove = (e) => {
		const root = this.#getRoot();
		if (!root) return;
		if (this.#isDisabled()) {
			if (root.opts.open.current) root.handleClose();
			return;
		}
		if (e.pointerType === "touch") return;
		if (get$2(this.#hasPointerMoveOpened)) return;
		this.#clearTransitCheck();
		root.provider.isPointerInTransit.current = false;
		root.onTriggerEnter(this.opts.id.current);
		set(this.#hasPointerMoveOpened, true);
	};
	#onpointerleave = (e) => {
		const root = this.#getRoot();
		if (!root) return;
		if (this.#isDisabled()) return;
		this.#clearTransitCheck();
		if (!root.isActiveTrigger(this.opts.id.current)) {
			set(this.#hasPointerMoveOpened, false);
			return;
		}
		const relatedTarget = e.relatedTarget;
		if (isElement$1(relatedTarget)) for (const record of root.registry.triggers.values()) {
			if (record.node !== relatedTarget) continue;
			if (root.provider.opts.skipDelayDuration.current > 0) {
				set(this.#hasPointerMoveOpened, false);
				return;
			}
			root.handleClose();
			set(this.#hasPointerMoveOpened, false);
			return;
		}
		root.onTriggerLeave();
		set(this.#hasPointerMoveOpened, false);
	};
	#onfocus = (e) => {
		const root = this.#getRoot();
		if (!root) return;
		if (this.#isPointerDown.current) return;
		if (this.#isDisabled()) {
			if (root.opts.open.current) root.handleClose();
			return;
		}
		if (root.ignoreNonKeyboardFocus && !isFocusVisible(e.currentTarget)) return;
		root.setActiveTrigger(this.opts.id.current);
		root.handleOpen();
	};
	#onblur = () => {
		const root = this.#getRoot();
		if (!root || this.#isDisabled()) return;
		root.handleClose();
	};
	#onclick = () => {
		const root = this.#getRoot();
		if (!root || root.disableCloseOnTriggerClick || this.#isDisabled()) return;
		root.handleClose();
	};
	#props = user_derived(() => {
		const root = this.#getRoot();
		const isOpenForTrigger = Boolean(root?.opts.open.current && root.isActiveTrigger(this.opts.id.current));
		const isDisabled = this.#isDisabled();
		return {
			id: this.opts.id.current,
			"aria-describedby": isOpenForTrigger ? root?.contentNode?.id : void 0,
			"data-state": isOpenForTrigger ? root?.stateAttr : "closed",
			"data-disabled": boolToEmptyStrOrUndef(isDisabled),
			"data-delay-duration": `${root?.delayDuration ?? 0}`,
			[tooltipAttrs.trigger]: "",
			tabindex: isDisabled ? void 0 : this.opts.tabindex.current,
			disabled: this.opts.disabled.current,
			onpointerup: this.#onpointerup,
			onpointerdown: this.#onpointerdown,
			onpointerenter: this.#onpointerenter,
			onpointermove: this.#onpointermove,
			onpointerleave: this.#onpointerleave,
			onfocus: this.#onfocus,
			onblur: this.#onblur,
			onclick: this.#onclick,
			...this.attachment
		};
	});
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
};
var TooltipContentState = class TooltipContentState {
	static create(opts) {
		return new TooltipContentState(opts, TooltipRootContext.get());
	}
	opts;
	root;
	attachment;
	constructor(opts, root) {
		this.opts = opts;
		this.root = root;
		this.attachment = attachRef(this.opts.ref, (v) => this.root.contentNode = v);
		new SafePolygon({
			triggerNode: () => this.root.triggerNode,
			contentNode: () => this.root.contentNode,
			enabled: () => this.root.opts.open.current && !this.root.disableHoverableContent,
			transitIntentTimeout: 180,
			ignoredTargets: () => {
				if (this.root.provider.opts.skipDelayDuration.current === 0) return [];
				const nodes = [];
				const activeTriggerNode = this.root.triggerNode;
				for (const record of this.root.registry.triggers.values()) if (record.node && record.node !== activeTriggerNode) nodes.push(record.node);
				return nodes;
			},
			onPointerExit: () => {
				if (this.root.provider.isTooltipOpen(this.root)) this.root.handleClose();
			}
		});
	}
	onInteractOutside = (e) => {
		if (isElement$1(e.target) && this.root.triggerNode?.contains(e.target) && this.root.disableCloseOnTriggerClick) {
			e.preventDefault();
			return;
		}
		this.opts.onInteractOutside.current(e);
		if (e.defaultPrevented) return;
		this.root.handleClose();
	};
	onEscapeKeydown = (e) => {
		this.opts.onEscapeKeydown.current?.(e);
		if (e.defaultPrevented) return;
		this.root.handleClose();
	};
	onOpenAutoFocus = (e) => {
		e.preventDefault();
	};
	onCloseAutoFocus = (e) => {
		e.preventDefault();
	};
	get shouldRender() {
		return this.root.contentPresence.shouldRender;
	}
	#snippetProps = user_derived(() => ({ open: this.root.opts.open.current }));
	get snippetProps() {
		return get$2(this.#snippetProps);
	}
	set snippetProps(value) {
		set(this.#snippetProps, value);
	}
	#props = user_derived(() => ({
		id: this.opts.id.current,
		"data-state": this.root.stateAttr,
		"data-disabled": boolToEmptyStrOrUndef(this.root.disabled),
		...getDataTransitionAttrs(this.root.contentPresence.transitionStatus),
		style: { outline: "none" },
		[tooltipAttrs.content]: "",
		...this.attachment
	}));
	get props() {
		return get$2(this.#props);
	}
	set props(value) {
		set(this.#props, value);
	}
	popperProps = {
		onInteractOutside: this.onInteractOutside,
		onEscapeKeydown: this.onEscapeKeydown,
		onOpenAutoFocus: this.onOpenAutoFocus,
		onCloseAutoFocus: this.onCloseAutoFocus
	};
};
//#endregion
//#region node_modules/bits-ui/dist/bits/tooltip/components/tooltip.svelte
function Tooltip$1($$anchor, $$props) {
	push($$props, true);
	let open = prop($$props, "open", 15, false), triggerId = prop($$props, "triggerId", 15, null), onOpenChange = prop($$props, "onOpenChange", 3, noop), onOpenChangeComplete = prop($$props, "onOpenChangeComplete", 3, noop);
	const rootState = TooltipRootState.create({
		open: boxWith(() => open(), (v) => {
			open(v);
			onOpenChange()(v);
		}),
		triggerId: boxWith(() => triggerId(), (v) => {
			triggerId(v);
		}),
		delayDuration: boxWith(() => $$props.delayDuration),
		disableCloseOnTriggerClick: boxWith(() => $$props.disableCloseOnTriggerClick),
		disableHoverableContent: boxWith(() => $$props.disableHoverableContent),
		ignoreNonKeyboardFocus: boxWith(() => $$props.ignoreNonKeyboardFocus),
		disabled: boxWith(() => $$props.disabled),
		onOpenChangeComplete: boxWith(() => onOpenChangeComplete()),
		tether: boxWith(() => $$props.tether)
	});
	Floating_layer($$anchor, {
		tooltip: true,
		children: ($$anchor, $$slotProps) => {
			var fragment_1 = comment();
			snippet(first_child(fragment_1), () => $$props.children ?? noop$1, () => ({
				open: rootState.opts.open.current,
				triggerId: rootState.activeTriggerId,
				payload: rootState.activePayload
			}));
			append($$anchor, fragment_1);
		},
		$$slots: { default: true }
	});
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/tooltip/components/tooltip-content.svelte
var root_4$8 = from_html(`<div><div><!></div></div>`);
var root_8 = from_html(`<div><div><!></div></div>`);
function Tooltip_content$1($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), ref = prop($$props, "ref", 15, null), side = prop($$props, "side", 3, "top"), sideOffset = prop($$props, "sideOffset", 3, 0), align = prop($$props, "align", 3, "center"), avoidCollisions = prop($$props, "avoidCollisions", 3, true), arrowPadding = prop($$props, "arrowPadding", 3, 0), sticky = prop($$props, "sticky", 3, "partial"), hideWhenDetached = prop($$props, "hideWhenDetached", 3, false), collisionPadding = prop($$props, "collisionPadding", 3, 0), onInteractOutside = prop($$props, "onInteractOutside", 3, noop), onEscapeKeydown = prop($$props, "onEscapeKeydown", 3, noop), forceMount = prop($$props, "forceMount", 3, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children",
		"child",
		"id",
		"ref",
		"side",
		"sideOffset",
		"align",
		"avoidCollisions",
		"arrowPadding",
		"sticky",
		"strategy",
		"hideWhenDetached",
		"customAnchor",
		"collisionPadding",
		"onInteractOutside",
		"onEscapeKeydown",
		"forceMount",
		"style"
	]);
	const contentState = TooltipContentState.create({
		id: boxWith(() => id()),
		ref: boxWith(() => ref(), (v) => ref(v)),
		onInteractOutside: boxWith(() => onInteractOutside()),
		onEscapeKeydown: boxWith(() => onEscapeKeydown())
	});
	const floatingProps = user_derived(() => ({
		side: side(),
		sideOffset: sideOffset(),
		align: align(),
		avoidCollisions: avoidCollisions(),
		arrowPadding: arrowPadding(),
		sticky: sticky(),
		hideWhenDetached: hideWhenDetached(),
		collisionPadding: collisionPadding(),
		strategy: $$props.strategy,
		customAnchor: $$props.customAnchor ?? contentState.root.triggerNode
	}));
	const mergedProps = user_derived(() => mergeProps(restProps, get$2(floatingProps), contentState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent_1 = ($$anchor) => {
		{
			const popper = ($$anchor, $$arg0) => {
				let props = () => $$arg0?.().props;
				let wrapperProps = () => $$arg0?.().wrapperProps;
				const finalWrapperProps = user_derived(() => mergeProps(wrapperProps(), { style: { pointerEvents: contentState.root.disableHoverableContent ? "none" : void 0 } }));
				const finalProps = user_derived(() => mergeProps(props(), { style: getFloatingContentCSSVars("tooltip") }, { style: $$props.style }));
				var fragment_2 = comment();
				var node_1 = first_child(fragment_2);
				var consequent = ($$anchor) => {
					var fragment_3 = comment();
					var node_2 = first_child(fragment_3);
					{
						let $0 = user_derived(() => ({
							props: get$2(finalProps),
							wrapperProps: get$2(finalWrapperProps),
							...contentState.snippetProps
						}));
						snippet(node_2, () => $$props.child, () => get$2($0));
					}
					append($$anchor, fragment_3);
				};
				var alternate = ($$anchor) => {
					var div = root_4$8();
					attribute_effect(div, () => ({ ...get$2(finalWrapperProps) }));
					var div_1 = child(div);
					attribute_effect(div_1, () => ({ ...get$2(finalProps) }));
					snippet(child(div_1), () => $$props.children ?? noop$1);
					reset(div_1);
					reset(div);
					append($$anchor, div);
				};
				if_block(node_1, ($$render) => {
					if ($$props.child) $$render(consequent);
					else $$render(alternate, -1);
				});
				append($$anchor, fragment_2);
			};
			let $0 = user_derived(() => contentState.root.disableHoverableContent ? "none" : "auto");
			Popper_layer_force_mount($$anchor, spread_props(() => get$2(mergedProps), () => contentState.popperProps, {
				get enabled() {
					return contentState.root.opts.open.current;
				},
				get id() {
					return id();
				},
				trapFocus: false,
				loop: false,
				preventScroll: false,
				forceMount: true,
				get ref() {
					return contentState.opts.ref;
				},
				tooltip: true,
				get shouldRender() {
					return contentState.shouldRender;
				},
				get contentPointerEvents() {
					return get$2($0);
				},
				popper,
				$$slots: { popper: true }
			}));
		}
	};
	var consequent_3 = ($$anchor) => {
		{
			const popper = ($$anchor, $$arg0) => {
				let props = () => $$arg0?.().props;
				let wrapperProps = () => $$arg0?.().wrapperProps;
				const finalWrapperProps = user_derived(() => mergeProps(wrapperProps(), { style: { pointerEvents: contentState.root.disableHoverableContent ? "none" : void 0 } }));
				const finalProps = user_derived(() => mergeProps(props(), { style: getFloatingContentCSSVars("tooltip") }, { style: $$props.style }));
				var fragment_5 = comment();
				var node_4 = first_child(fragment_5);
				var consequent_2 = ($$anchor) => {
					var fragment_6 = comment();
					var node_5 = first_child(fragment_6);
					{
						let $0 = user_derived(() => ({
							props: get$2(finalProps),
							wrapperProps: get$2(finalWrapperProps),
							...contentState.snippetProps
						}));
						snippet(node_5, () => $$props.child, () => get$2($0));
					}
					append($$anchor, fragment_6);
				};
				var alternate_1 = ($$anchor) => {
					var div_2 = root_8();
					attribute_effect(div_2, () => ({ ...get$2(finalWrapperProps) }));
					var div_3 = child(div_2);
					attribute_effect(div_3, () => ({ ...get$2(finalProps) }));
					snippet(child(div_3), () => $$props.children ?? noop$1);
					reset(div_3);
					reset(div_2);
					append($$anchor, div_2);
				};
				if_block(node_4, ($$render) => {
					if ($$props.child) $$render(consequent_2);
					else $$render(alternate_1, -1);
				});
				append($$anchor, fragment_5);
			};
			let $0 = user_derived(() => contentState.root.disableHoverableContent ? "none" : "auto");
			Popper_layer($$anchor, spread_props(() => get$2(mergedProps), () => contentState.popperProps, {
				get open() {
					return contentState.root.opts.open.current;
				},
				get id() {
					return id();
				},
				trapFocus: false,
				loop: false,
				preventScroll: false,
				forceMount: false,
				get ref() {
					return contentState.opts.ref;
				},
				tooltip: true,
				get shouldRender() {
					return contentState.shouldRender;
				},
				get contentPointerEvents() {
					return get$2($0);
				},
				popper,
				$$slots: { popper: true }
			}));
		}
	};
	if_block(node, ($$render) => {
		if (forceMount()) $$render(consequent_1);
		else if (!forceMount()) $$render(consequent_3, 1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/tooltip/components/tooltip-trigger.svelte
var root_2$12 = from_html(`<button><!></button>`);
function Tooltip_trigger$1($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), disabled = prop($$props, "disabled", 3, false), type = prop($$props, "type", 3, "button"), tabindex = prop($$props, "tabindex", 3, 0), ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children",
		"child",
		"id",
		"disabled",
		"payload",
		"tether",
		"type",
		"tabindex",
		"ref"
	]);
	const triggerState = TooltipTriggerState.create({
		id: boxWith(() => id()),
		disabled: boxWith(() => disabled() ?? false),
		tabindex: boxWith(() => tabindex() ?? 0),
		payload: boxWith(() => $$props.payload),
		tether: boxWith(() => $$props.tether),
		ref: boxWith(() => ref(), (v) => ref(v))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, triggerState.props, { type: type() }));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.child, () => ({ props: get$2(mergedProps) }));
		append($$anchor, fragment_1);
	};
	var alternate = ($$anchor) => {
		var button = root_2$12();
		attribute_effect(button, () => ({ ...get$2(mergedProps) }));
		snippet(child(button), () => $$props.children ?? noop$1);
		reset(button);
		append($$anchor, button);
	};
	if_block(node, ($$render) => {
		if ($$props.child) $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/tooltip/components/tooltip-arrow.svelte
function Tooltip_arrow($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref"
	]);
	Floating_layer_arrow($$anchor, spread_props(() => restProps, {
		get ref() {
			return ref();
		},
		set ref($$value) {
			ref($$value);
		}
	}));
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/tooltip/components/tooltip-provider.svelte
function Tooltip_provider$1($$anchor, $$props) {
	push($$props, true);
	let delayDuration = prop($$props, "delayDuration", 3, 700), disableCloseOnTriggerClick = prop($$props, "disableCloseOnTriggerClick", 3, false), disableHoverableContent = prop($$props, "disableHoverableContent", 3, false), disabled = prop($$props, "disabled", 3, false), ignoreNonKeyboardFocus = prop($$props, "ignoreNonKeyboardFocus", 3, false), skipDelayDuration = prop($$props, "skipDelayDuration", 3, 300);
	TooltipProviderState.create({
		delayDuration: boxWith(() => delayDuration()),
		disableCloseOnTriggerClick: boxWith(() => disableCloseOnTriggerClick()),
		disableHoverableContent: boxWith(() => disableHoverableContent()),
		disabled: boxWith(() => disabled()),
		ignoreNonKeyboardFocus: boxWith(() => ignoreNonKeyboardFocus()),
		skipDelayDuration: boxWith(() => skipDelayDuration())
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.children ?? noop$1);
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/separator/separator.svelte
function Separator($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), dataSlot = prop($$props, "data-slot", 3, "separator"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"data-slot"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	{
		let $0 = user_derived(() => cn$1("bg-border shrink-0 data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:w-px", "data-[orientation=vertical]:h-full", $$props.class));
		component(node, () => Separator$1, ($$anchor, SeparatorPrimitive_Root) => {
			SeparatorPrimitive_Root($$anchor, spread_props({
				get "data-slot"() {
					return dataSlot();
				},
				get class() {
					return get$2($0);
				}
			}, () => restProps, {
				get ref() {
					return ref();
				},
				set ref($$value) {
					ref($$value);
				}
			}));
		});
	}
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region extension/utils/common/functions/formatting.ts
var REGEXES = {
	convertToNumber: /-?[\d,]+(\.\d+)?/,
	formatNumber: /\B(?=(\d{3})+(?!\d))/g
};
function dropDecimals(number) {
	return parseInt(number.toString());
}
function toSeconds(milliseconds) {
	if (!milliseconds) return toSeconds(Date.now());
	else if (typeof milliseconds === "object" && milliseconds instanceof Date) return toSeconds(milliseconds.getTime());
	else if (!Number.isNaN(milliseconds)) return Math.trunc(milliseconds / 1e3);
	else return toSeconds(Date.now());
}
function toMultipleDigits(number, digits = 2) {
	if (number === void 0) return void 0;
	return number.toString().length < digits ? toMultipleDigits(`0${number}`, digits) : number.toString();
}
function formatTime(time, partialOptions = {}) {
	if (typeof time === "number") return formatTime({ milliseconds: time }, partialOptions);
	else if (typeof time === "string") return formatTime(new Date(time), partialOptions);
	else if (time instanceof Date) return formatTime({ milliseconds: time.getTime() }, partialOptions);
	const options = {
		type: "normal",
		showDays: false,
		hideHours: false,
		hideSeconds: false,
		short: false,
		extraShort: false,
		agoFilter: void 0,
		daysToHours: false,
		truncateSeconds: false,
		...partialOptions
	};
	let millis;
	if ("milliseconds" in time) millis = time.milliseconds;
	else if ("seconds" in time) millis = time.seconds * TO_MILLIS.SECONDS;
	let date, parts;
	switch (options.type) {
		case "normal": {
			date = new Date(millis);
			let seconds, minutes, hours;
			if (settings.formatting.tct) {
				seconds = date.getUTCSeconds();
				minutes = date.getUTCMinutes();
				hours = date.getUTCHours();
			} else {
				seconds = date.getSeconds();
				minutes = date.getMinutes();
				hours = date.getHours();
			}
			const secondsText = options.hideSeconds ? void 0 : toMultipleDigits(seconds);
			const minutesText = toMultipleDigits(minutes);
			let hoursText = toMultipleDigits(hours);
			switch (settings.formatting.time) {
				case "us": {
					const afternoon = hours >= 12;
					hoursText = toMultipleDigits(hours % 12 || 12);
					return secondsText ? `${hoursText}:${minutesText}:${secondsText} ${afternoon ? "PM" : "AM"}` : `${hoursText}:${minutesText} ${afternoon ? "PM" : "AM"}`;
				}
				default: return secondsText ? `${hoursText}:${minutesText}:${secondsText}` : `${hoursText}:${minutesText}`;
			}
		}
		case "timer": {
			date = new Date(millis);
			parts = [];
			if (options.showDays) parts.push(Math.floor(date.getTime() / TO_MILLIS.DAYS));
			if (!options.hideHours) parts.push(date.getUTCHours() + (options.daysToHours ? 24 * Math.floor(millis / TO_MILLIS.DAYS) : 0));
			parts.push(date.getUTCMinutes());
			if (!options.hideSeconds) parts.push(date.getUTCSeconds());
			let timerText = parts.map((p) => toMultipleDigits(p, 2)).join(":");
			if (options.short && options.showDays && timerText.startsWith("00:")) timerText = timerText.slice(3);
			return timerText;
		}
		case "wordTimer": return formatTimeAsWordTimer(millis, options);
		case "ago": {
			let timeAgo = Math.floor(Date.now() - millis);
			let token = "ago";
			if (timeAgo < 0) {
				token = "from now";
				timeAgo = Math.abs(timeAgo);
			}
			const UNITS = [
				{
					unit: options.short ? "y" : "year",
					millis: TO_MILLIS.DAYS * 370,
					getter: () => {
						const to = /* @__PURE__ */ new Date();
						const from = new Date(millis);
						let years = to.getFullYear() - from.getFullYear();
						if (to.getMonth() > from.getMonth() || to.getMonth() === from.getMonth() && to.getDay() > from.getDay()) years--;
						return years;
					}
				},
				{
					unit: options.short ? "mth" : "month",
					millis: TO_MILLIS.DAYS * 30,
					getter: () => {
						const to = /* @__PURE__ */ new Date();
						const from = new Date(millis);
						let months = (to.getFullYear() - from.getFullYear()) * 12;
						months += to.getMonth() - from.getMonth();
						if (to.getDay() > from.getDay()) months--;
						return months;
					}
				},
				{
					unit: options.short ? "d" : "day",
					millis: TO_MILLIS.DAYS
				},
				{
					unit: options.short ? "hr" : "hour",
					millis: TO_MILLIS.HOURS
				},
				{
					unit: options.short ? "min" : "minute",
					millis: TO_MILLIS.MINUTES
				},
				{
					unit: options.short ? "sec" : "second",
					millis: TO_MILLIS.SECONDS
				},
				{
					text: options.short ? "now" : "just now",
					millis: 0
				}
			];
			let _units = UNITS;
			if (options.agoFilter) _units = UNITS.filter((value) => value.millis <= options.agoFilter);
			for (const unit of _units) {
				if (timeAgo < unit.millis) continue;
				if (unit.unit) {
					const amount = unit.getter ? unit.getter() : Math.floor(timeAgo / unit.millis);
					return `${amount} ${unit.unit}${applyPlural(amount)} ${token}`;
				} else if (unit.text) return unit.text;
			}
			return timeAgo.toString();
		}
		default: throw new Error("Invalid formatTime type.");
	}
}
function formatTimeAsWordTimer(millis, options) {
	const date = new Date(millis);
	let hasShownDays = false;
	let hasShownHours = false;
	const parts = [];
	if (options.showDays && dropDecimals(date.getTime() / TO_MILLIS.DAYS) > 0) {
		hasShownDays = true;
		parts.push(formatUnit(Math.floor(date.getTime() / TO_MILLIS.DAYS), {
			normal: "day",
			short: "day",
			extraShort: "d"
		}));
	}
	if (!options.hideHours && date.getUTCHours()) {
		hasShownHours = true;
		parts.push(formatUnit(date.getUTCHours(), {
			normal: "hour",
			short: "hr",
			extraShort: "h"
		}));
	}
	if (date.getUTCMinutes()) parts.push(formatUnit(date.getUTCMinutes(), {
		normal: "minute",
		short: "min",
		extraShort: "m"
	}));
	if (!options.hideSeconds && date.getUTCSeconds() && (!options.truncateSeconds || !(hasShownDays || hasShownHours))) parts.push(formatUnit(date.getUTCSeconds(), {
		normal: "second",
		short: "sec",
		extraShort: "s"
	}));
	if (parts.length > 1 && !options.extraShort) parts.splice(parts.length - 1, 0, "and");
	function formatUnit(amount, unit) {
		let formatted = `${amount}`;
		if (options.extraShort) formatted += unit.extraShort;
		else if (options.short) formatted += ` ${unit.short}${applyPlural(amount)}`;
		else formatted += ` ${unit.normal}${applyPlural(amount)}`;
		return formatted;
	}
	return parts.join(" ");
}
function formatDate(date, partialOptions = {}) {
	if (typeof date === "number") return formatDate({ milliseconds: date }, partialOptions);
	else if (typeof date === "string") return formatDate({ milliseconds: new Date(date).getTime() }, partialOptions);
	else if (date instanceof Date) return formatDate({ milliseconds: date.getTime() }, partialOptions);
	const options = {
		showYear: false,
		...partialOptions
	};
	let millis;
	if ("milliseconds" in date) millis = date.milliseconds;
	else if ("seconds" in date) millis = date.seconds * 1e3;
	const _date = new Date(millis);
	let day, month, year;
	if (settings.formatting.tct) {
		day = _date.getUTCDate();
		month = _date.getUTCMonth() + 1;
		year = _date.getUTCFullYear();
	} else {
		day = _date.getDate();
		month = _date.getMonth() + 1;
		year = _date.getFullYear();
	}
	const parts = [];
	let separator;
	switch (settings.formatting.date) {
		case "us":
			separator = "/";
			parts.push(month, day);
			if (options.showYear) parts.push(year);
			break;
		case "iso":
			separator = "-";
			if (options.showYear) parts.push(year);
			parts.push(month, day);
			break;
		case "eu":
			separator = ".";
			parts.push(day, month);
			if (options.showYear) parts.push(year);
			break;
	}
	return parts.map((p) => toMultipleDigits(p)).join(separator);
}
function formatNumber(number, partialOptions = {}) {
	const options = {
		shorten: false,
		formatter: void 0,
		decimals: 0,
		currency: false,
		forceOperation: false,
		roman: false,
		...partialOptions
	};
	if (typeof number !== "number") if (Number.isNaN(parseInt(number))) return number;
	else number = parseFloat(number);
	if (number === Number.POSITIVE_INFINITY) return "∞";
	if (options.decimals !== void 0) number = parseFloat(number.toFixed(options.decimals));
	if (options.formatter) return options.formatter.format(number);
	if (options.roman) {
		if (number === 0) return "";
		else if (number < 0) throw "Roman numbers can only be positive!";
		const ROMAN = [
			[1e3, "M"],
			[900, "CM"],
			[500, "D"],
			[400, "CD"],
			[100, "C"],
			[90, "XC"],
			[50, "L"],
			[40, "XL"],
			[10, "X"],
			[9, "IX"],
			[5, "V"],
			[4, "IV"],
			[1, "I"]
		];
		return toRoman(number);
		function toRoman(number) {
			if (number === 0) return "";
			for (const [value, character] of ROMAN) {
				if (number < value) continue;
				return character + toRoman(number - value);
			}
			return "N/A";
		}
	}
	const abstract = Math.abs(number);
	const operation = number < 0 ? "-" : options.forceOperation ? "+" : "";
	let text;
	if (options.shorten) {
		const version = options.shorten === true ? 1 : options.shorten;
		const decimals = options.decimals !== -1 ? options.decimals : 3;
		const words = (() => {
			switch (version) {
				case 1: return {
					thousand: "k",
					million: "mil",
					billion: "bill"
				};
				case 2:
				case 3: return {
					thousand: "k",
					million: "m",
					billion: "b"
				};
			}
		})();
		if (version === 1 || version === 2) {
			if (abstract >= 1e9) if (abstract % 1e9 === 0) text = (abstract / 1e9).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") + words.billion;
			else text = (abstract / 1e9).toFixed(3) + words.billion;
			else if (abstract >= 1e6) if (abstract % 1e6 === 0) text = abstract / 1e6 + words.million;
			else text = (abstract / 1e6).toFixed(3) + words.million;
			else if (abstract >= 1e3) {
				if (abstract % 1e3 === 0) text = abstract / 1e3 + words.thousand;
			}
		} else if (abstract >= 1e9) if (abstract % 1e9 === 0) text = abstract / 1e9 + words.billion;
		else text = parseFloat((abstract / 1e9).toFixed(decimals)) + words.billion;
		else if (abstract >= 1e6) if (abstract % 1e6 === 0) text = abstract / 1e6 + words.million;
		else text = parseFloat((abstract / 1e6).toFixed(decimals)) + words.million;
		else if (abstract >= 1e3) {
			if (abstract % 1e3 === 0) text = abstract / 1e3 + words.thousand;
			else if (abstract % 100 === 0) text = abstract / 1e3 + words.thousand;
		}
	}
	if (!text) text = abstract.toString().replace(REGEXES.formatNumber, ",");
	return `${operation}${options.currency ? "$" : ""}${text}`;
}
function capitalizeText(text, partialOptions = {}) {
	if (!{
		everyWord: false,
		...partialOptions
	}.everyWord) return text[0].toUpperCase() + text.slice(1);
	return text.trim().split(" ").map((word) => capitalizeText(word)).join(" ").trim();
}
function applyPlural(check) {
	return check !== 1 ? "s" : "";
}
function daySuffix(number) {
	const last = number % 10, double = number % 100;
	if (last === 1 && double !== 11) return `${number}st`;
	else if (last === 2 && double !== 12) return `${number}nd`;
	else if (last === 3 && double !== 13) return `${number}rd`;
	else return `${number}th`;
}
function formatBytes(bytes, partialOptions = {}) {
	const options = {
		decimals: 2,
		...partialOptions
	};
	if (bytes === 0) return "0 bytes";
	else if (bytes < 0) throw "Negative bytes are impossible";
	const unitExponent = 1024;
	const units = [
		"bytes",
		"KB",
		"MB",
		"GB",
		"TB",
		"PB",
		"EB",
		"ZB",
		"YB"
	];
	const effectiveUnit = Math.floor(Math.log(bytes) / Math.log(unitExponent));
	return `${formatNumber(bytes / unitExponent ** effectiveUnit, { decimals: options.decimals })} ${units[effectiveUnit]}`;
}
//#endregion
//#region node_modules/tailwind-variants/dist/chunk-LQJYWU4O.js
var SPACE_REGEX = /\s+/g;
var removeExtraSpaces = (str) => {
	if (typeof str !== "string" || !str) return str;
	return str.replace(SPACE_REGEX, " ").trim();
};
var cx = (...classnames) => {
	const classList = [];
	const buildClassString = (input) => {
		if (!input && input !== 0 && input !== 0n) return;
		if (Array.isArray(input)) {
			for (let i = 0, len = input.length; i < len; i++) buildClassString(input[i]);
			return;
		}
		const type = typeof input;
		if (type === "string" || type === "number" || type === "bigint") {
			if (type === "number" && input !== input) return;
			classList.push(String(input));
		} else if (type === "object") {
			const keys = Object.keys(input);
			for (let i = 0, len = keys.length; i < len; i++) {
				const key = keys[i];
				if (input[key]) classList.push(key);
			}
		}
	};
	for (let i = 0, len = classnames.length; i < len; i++) {
		const c = classnames[i];
		if (c !== null && c !== void 0) buildClassString(c);
	}
	return classList.length > 0 ? removeExtraSpaces(classList.join(" ")) : void 0;
};
var falsyToString = (value) => value === false ? "false" : value === true ? "true" : value === 0 ? "0" : value;
var isEmptyObject = (obj) => {
	if (!obj || typeof obj !== "object") return true;
	for (const _ in obj) return false;
	return true;
};
var isEqual = (obj1, obj2) => {
	if (obj1 === obj2) return true;
	if (!obj1 || !obj2) return false;
	const keys1 = Object.keys(obj1);
	const keys2 = Object.keys(obj2);
	if (keys1.length !== keys2.length) return false;
	for (let i = 0; i < keys1.length; i++) {
		const key = keys1[i];
		if (!keys2.includes(key)) return false;
		if (obj1[key] !== obj2[key]) return false;
	}
	return true;
};
var joinObjects = (obj1, obj2) => {
	for (const key in obj2) if (Object.prototype.hasOwnProperty.call(obj2, key)) {
		const val2 = obj2[key];
		if (key in obj1) obj1[key] = cx(obj1[key], val2);
		else obj1[key] = val2;
	}
	return obj1;
};
var flat = (arr, target) => {
	for (let i = 0; i < arr.length; i++) {
		const el = arr[i];
		if (Array.isArray(el)) flat(el, target);
		else if (el) target.push(el);
	}
};
var flatMergeArrays = (...arrays) => {
	const result = [];
	flat(arrays, result);
	const filtered = [];
	for (let i = 0; i < result.length; i++) if (result[i]) filtered.push(result[i]);
	return filtered;
};
var mergeObjects = (obj1, obj2) => {
	const result = {};
	for (const key in obj1) {
		const val1 = obj1[key];
		if (key in obj2) {
			const val2 = obj2[key];
			if (Array.isArray(val1) || Array.isArray(val2)) result[key] = flatMergeArrays(val2, val1);
			else if (typeof val1 === "object" && typeof val2 === "object" && val1 && val2) result[key] = mergeObjects(val1, val2);
			else result[key] = val2 + " " + val1;
		} else result[key] = val1;
	}
	for (const key in obj2) if (!(key in obj1)) result[key] = obj2[key];
	return result;
};
//#endregion
//#region node_modules/tailwind-variants/dist/chunk-RZF76H2U.js
var defaultConfig = {
	twMerge: true,
	twMergeConfig: {}
};
function createState() {
	let cachedTwMerge = null;
	let cachedTwMergeConfig = {};
	let didTwMergeConfigChange = false;
	return {
		get cachedTwMerge() {
			return cachedTwMerge;
		},
		set cachedTwMerge(value) {
			cachedTwMerge = value;
		},
		get cachedTwMergeConfig() {
			return cachedTwMergeConfig;
		},
		set cachedTwMergeConfig(value) {
			cachedTwMergeConfig = value;
		},
		get didTwMergeConfigChange() {
			return didTwMergeConfigChange;
		},
		set didTwMergeConfigChange(value) {
			didTwMergeConfigChange = value;
		},
		reset() {
			cachedTwMerge = null;
			cachedTwMergeConfig = {};
			didTwMergeConfigChange = false;
		}
	};
}
var state = createState();
var getTailwindVariants = (cn) => {
	const tv = (options, configProp) => {
		const { extend = null, slots: slotProps = {}, variants: variantsProps = {}, compoundVariants: compoundVariantsProps = [], compoundSlots = [], defaultVariants: defaultVariantsProps = {} } = options;
		const config = {
			...defaultConfig,
			...configProp
		};
		const base = extend?.base ? cx(extend.base, options?.base) : options?.base;
		const variants = extend?.variants && !isEmptyObject(extend.variants) ? mergeObjects(variantsProps, extend.variants) : variantsProps;
		const defaultVariants = extend?.defaultVariants && !isEmptyObject(extend.defaultVariants) ? {
			...extend.defaultVariants,
			...defaultVariantsProps
		} : defaultVariantsProps;
		if (!isEmptyObject(config.twMergeConfig) && !isEqual(config.twMergeConfig, state.cachedTwMergeConfig)) {
			state.didTwMergeConfigChange = true;
			state.cachedTwMergeConfig = config.twMergeConfig;
		}
		const isExtendedSlotsEmpty = isEmptyObject(extend?.slots);
		const componentSlots = !isEmptyObject(slotProps) ? {
			base: cx(options?.base, isExtendedSlotsEmpty && extend?.base),
			...slotProps
		} : {};
		const slots = isExtendedSlotsEmpty ? componentSlots : joinObjects({ ...extend?.slots }, isEmptyObject(componentSlots) ? { base: options?.base } : componentSlots);
		const compoundVariants = isEmptyObject(extend?.compoundVariants) ? compoundVariantsProps : flatMergeArrays(extend?.compoundVariants, compoundVariantsProps);
		const component = (props) => {
			if (isEmptyObject(variants) && isEmptyObject(slotProps) && isExtendedSlotsEmpty) return cn(base, props?.class, props?.className)(config);
			if (compoundVariants && !Array.isArray(compoundVariants)) throw new TypeError(`The "compoundVariants" prop must be an array. Received: ${typeof compoundVariants}`);
			if (compoundSlots && !Array.isArray(compoundSlots)) throw new TypeError(`The "compoundSlots" prop must be an array. Received: ${typeof compoundSlots}`);
			const getVariantValue = (variant, vrs = variants, _slotKey = null, slotProps2 = null) => {
				const variantObj = vrs[variant];
				if (!variantObj || isEmptyObject(variantObj)) return null;
				const variantProp = slotProps2?.[variant] ?? props?.[variant];
				if (variantProp === null) return null;
				const variantKey = falsyToString(variantProp);
				if (typeof variantKey === "object") return null;
				const defaultVariantProp = defaultVariants?.[variant];
				return variantObj[(variantKey != null ? variantKey : falsyToString(defaultVariantProp)) || "false"];
			};
			const getVariantClassNames = () => {
				if (!variants) return null;
				const keys = Object.keys(variants);
				const result = [];
				for (let i = 0; i < keys.length; i++) {
					const value = getVariantValue(keys[i], variants);
					if (value) result.push(value);
				}
				return result;
			};
			const getVariantClassNamesBySlotKey = (slotKey, slotProps2) => {
				if (!variants || typeof variants !== "object") return null;
				const result = [];
				for (const variant in variants) {
					const variantValue = getVariantValue(variant, variants, slotKey, slotProps2);
					const value = slotKey === "base" && typeof variantValue === "string" ? variantValue : variantValue && variantValue[slotKey];
					if (value) result.push(value);
				}
				return result;
			};
			const propsWithoutUndefined = {};
			for (const prop in props) {
				const value = props[prop];
				if (value !== void 0) propsWithoutUndefined[prop] = value;
			}
			const getCompleteProps = (key, slotProps2) => {
				const initialProp = typeof props?.[key] === "object" ? { [key]: props[key]?.initial } : {};
				return {
					...defaultVariants,
					...propsWithoutUndefined,
					...initialProp,
					...slotProps2
				};
			};
			const getCompoundVariantsValue = (cv = [], slotProps2) => {
				const result = [];
				const cvLength = cv.length;
				for (let i = 0; i < cvLength; i++) {
					const { class: tvClass, className: tvClassName, ...compoundVariantOptions } = cv[i];
					let isValid = true;
					const completeProps = getCompleteProps(null, slotProps2);
					for (const key in compoundVariantOptions) {
						const value = compoundVariantOptions[key];
						const completePropsValue = completeProps[key];
						if (Array.isArray(value)) {
							if (!value.includes(completePropsValue)) {
								isValid = false;
								break;
							}
						} else {
							if ((value == null || value === false) && (completePropsValue == null || completePropsValue === false)) continue;
							if (completePropsValue !== value) {
								isValid = false;
								break;
							}
						}
					}
					if (isValid) {
						if (tvClass) result.push(tvClass);
						if (tvClassName) result.push(tvClassName);
					}
				}
				return result;
			};
			const getCompoundVariantClassNamesBySlot = (slotProps2) => {
				const compoundClassNames = getCompoundVariantsValue(compoundVariants, slotProps2);
				if (!Array.isArray(compoundClassNames)) return compoundClassNames;
				const result = {};
				const cnFn = cn;
				for (let i = 0; i < compoundClassNames.length; i++) {
					const className = compoundClassNames[i];
					if (typeof className === "string") result.base = cnFn(result.base, className)(config);
					else if (typeof className === "object") for (const slot in className) result[slot] = cnFn(result[slot], className[slot])(config);
				}
				return result;
			};
			const getCompoundSlotClassNameBySlot = (slotProps2) => {
				if (compoundSlots.length < 1) return null;
				const result = {};
				const completeProps = getCompleteProps(null, slotProps2);
				for (let i = 0; i < compoundSlots.length; i++) {
					const { slots: slots2 = [], class: slotClass, className: slotClassName, ...slotVariants } = compoundSlots[i];
					if (!isEmptyObject(slotVariants)) {
						let isValid = true;
						for (const key in slotVariants) {
							const completePropsValue = completeProps[key];
							const slotVariantValue = slotVariants[key];
							if (completePropsValue === void 0 || (Array.isArray(slotVariantValue) ? !slotVariantValue.includes(completePropsValue) : slotVariantValue !== completePropsValue)) {
								isValid = false;
								break;
							}
						}
						if (!isValid) continue;
					}
					for (let j = 0; j < slots2.length; j++) {
						const slotName = slots2[j];
						if (!result[slotName]) result[slotName] = [];
						result[slotName].push([slotClass, slotClassName]);
					}
				}
				return result;
			};
			if (!isEmptyObject(slotProps) || !isExtendedSlotsEmpty) {
				const slotsFns = {};
				if (typeof slots === "object" && !isEmptyObject(slots)) {
					const cnFn = cn;
					for (const slotKey in slots) slotsFns[slotKey] = (slotProps2) => {
						const compoundVariantClasses = getCompoundVariantClassNamesBySlot(slotProps2);
						const compoundSlotClasses = getCompoundSlotClassNameBySlot(slotProps2);
						return cnFn(slots[slotKey], getVariantClassNamesBySlotKey(slotKey, slotProps2), compoundVariantClasses ? compoundVariantClasses[slotKey] : void 0, compoundSlotClasses ? compoundSlotClasses[slotKey] : void 0, slotProps2?.class, slotProps2?.className)(config);
					};
				}
				return slotsFns;
			}
			return cn(base, getVariantClassNames(), getCompoundVariantsValue(compoundVariants), props?.class, props?.className)(config);
		};
		const getVariantKeys = () => {
			if (!variants || typeof variants !== "object") return;
			return Object.keys(variants);
		};
		component.variantKeys = getVariantKeys();
		component.extend = extend;
		component.base = base;
		component.slots = slots;
		component.variants = variants;
		component.defaultVariants = defaultVariants;
		component.compoundSlots = compoundSlots;
		component.compoundVariants = compoundVariants;
		return component;
	};
	const createTV = (configProp) => {
		return (options, config) => tv(options, config ? mergeObjects(configProp, config) : configProp);
	};
	return {
		tv,
		createTV
	};
};
//#endregion
//#region node_modules/tailwind-variants/dist/index.js
var createTwMerge = (cachedTwMergeConfig) => {
	return isEmptyObject(cachedTwMergeConfig) ? twMerge : extendTailwindMerge({
		...cachedTwMergeConfig,
		extend: {
			theme: cachedTwMergeConfig.theme,
			classGroups: cachedTwMergeConfig.classGroups,
			conflictingClassGroupModifiers: cachedTwMergeConfig.conflictingClassGroupModifiers,
			conflictingClassGroups: cachedTwMergeConfig.conflictingClassGroups,
			...cachedTwMergeConfig.extend
		}
	});
};
var executeMerge = (classnames, config) => {
	const base = cx(classnames);
	if (!base || !(config?.twMerge ?? true)) return base;
	if (!state.cachedTwMerge || state.didTwMergeConfigChange) {
		state.didTwMergeConfigChange = false;
		state.cachedTwMerge = createTwMerge(state.cachedTwMergeConfig);
	}
	return state.cachedTwMerge(base) || void 0;
};
var cnMerge = (...classnames) => {
	return (config) => executeMerge(classnames, config);
};
var { createTV, tv } = getTailwindVariants(cnMerge);
//#endregion
//#region extension/svelte/components/ui/button/helper.ts
var buttonVariants = tv({
	base: "focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 rounded-lg border border-transparent bg-clip-padding text-sm font-medium focus-visible:ring-3 active:not-aria-[haspopup]:translate-y-px aria-invalid:ring-3 [&_svg:not([class*='size-'])]:size-4 group/button inline-flex shrink-0 cursor-pointer items-center justify-center whitespace-nowrap transition-all outline-none select-none disabled:cursor-not-allowed disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
	variants: {
		variant: {
			default: "bg-primary text-primary-foreground [a]:hover:bg-primary/80",
			outline: "border-border bg-background hover:bg-muted hover:text-foreground dark:bg-input/30 dark:border-input dark:hover:bg-input/50 aria-expanded:bg-muted aria-expanded:text-foreground",
			secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80 aria-expanded:bg-secondary aria-expanded:text-secondary-foreground",
			ghost: "hover:bg-muted hover:text-foreground dark:hover:bg-muted/50 aria-expanded:bg-muted aria-expanded:text-foreground",
			destructive: "bg-destructive/10 hover:bg-destructive/20 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 dark:bg-destructive/20 text-destructive focus-visible:border-destructive/40 dark:hover:bg-destructive/30",
			link: "text-primary underline-offset-4 hover:underline"
		},
		size: {
			default: "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
			xs: "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3",
			sm: "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
			lg: "h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
			icon: "size-8",
			"icon-xs": "size-6 rounded-[min(var(--radius-md),10px)] in-data-[slot=button-group]:rounded-lg [&_svg:not([class*='size-'])]:size-3",
			"icon-sm": "size-7 rounded-[min(var(--radius-md),12px)] in-data-[slot=button-group]:rounded-lg",
			"icon-lg": "size-9"
		}
	},
	defaultVariants: {
		variant: "default",
		size: "default"
	}
});
//#endregion
//#region extension/svelte/components/ui/button/button.svelte
var root_1$2 = from_html(`<a><!></a>`);
var root_2$11 = from_html(`<button><!></button>`);
function Button($$anchor, $$props) {
	push($$props, true);
	let variant = prop($$props, "variant", 3, "default"), size = prop($$props, "size", 3, "default"), ref = prop($$props, "ref", 15, null), href = prop($$props, "href", 3, void 0), type = prop($$props, "type", 3, "button"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"class",
		"variant",
		"size",
		"ref",
		"href",
		"type",
		"disabled",
		"children"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var a = root_1$2();
		attribute_effect(a, ($0) => ({
			"data-slot": "button",
			class: $0,
			href: $$props.disabled ? void 0 : href(),
			"aria-disabled": $$props.disabled,
			role: $$props.disabled ? "link" : void 0,
			tabindex: $$props.disabled ? -1 : void 0,
			...restProps
		}), [() => cn$1(buttonVariants({
			variant: variant(),
			size: size()
		}), $$props.class)]);
		snippet(child(a), () => $$props.children ?? noop$1);
		reset(a);
		bind_this(a, ($$value) => ref($$value), () => ref());
		append($$anchor, a);
	};
	var alternate = ($$anchor) => {
		var button = root_2$11();
		attribute_effect(button, ($0) => ({
			"data-slot": "button",
			class: $0,
			type: type(),
			disabled: $$props.disabled,
			...restProps
		}), [() => cn$1(buttonVariants({
			variant: variant(),
			size: size()
		}), $$props.class)]);
		snippet(child(button), () => $$props.children ?? noop$1);
		reset(button);
		bind_this(button, ($$value) => ref($$value), () => ref());
		append($$anchor, button);
	};
	if_block(node, ($$render) => {
		if (href()) $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/context.js
var contextKey = Symbol("phosphor-svelte");
/**
*
* @returns {import("./shared").IconContextProps["values"]}
*/
function getIconContext() {
	if (hasContext(contextKey)) return getContext(contextKey);
	return {};
}
//#endregion
//#region node_modules/phosphor-svelte/lib/Spinner.svelte
var root_2$10 = from_svg(`<path d="M140,32V64a12,12,0,0,1-24,0V32a12,12,0,0,1,24,0Zm33.25,62.75a12,12,0,0,0,8.49-3.52L204.37,68.6a12,12,0,0,0-17-17L164.77,74.26a12,12,0,0,0,8.48,20.49ZM224,116H192a12,12,0,0,0,0,24h32a12,12,0,0,0,0-24Zm-42.26,48.77a12,12,0,1,0-17,17l22.63,22.63a12,12,0,0,0,17-17ZM128,180a12,12,0,0,0-12,12v32a12,12,0,0,0,24,0V192A12,12,0,0,0,128,180ZM74.26,164.77,51.63,187.4a12,12,0,0,0,17,17l22.63-22.63a12,12,0,1,0-17-17ZM76,128a12,12,0,0,0-12-12H32a12,12,0,0,0,0,24H64A12,12,0,0,0,76,128ZM68.6,51.63a12,12,0,1,0-17,17L74.26,91.23a12,12,0,0,0,17-17Z"></path>`);
var root_3$7 = from_svg(`<path d="M224,128a96,96,0,1,1-96-96A96,96,0,0,1,224,128Z" opacity="0.2"></path><path d="M136,32V64a8,8,0,0,1-16,0V32a8,8,0,0,1,16,0Zm37.25,58.75a8,8,0,0,0,5.66-2.35l22.63-22.62a8,8,0,0,0-11.32-11.32L167.6,77.09a8,8,0,0,0,5.65,13.66ZM224,120H192a8,8,0,0,0,0,16h32a8,8,0,0,0,0-16Zm-45.09,47.6a8,8,0,0,0-11.31,11.31l22.62,22.63a8,8,0,0,0,11.32-11.32ZM128,184a8,8,0,0,0-8,8v32a8,8,0,0,0,16,0V192A8,8,0,0,0,128,184ZM77.09,167.6,54.46,190.22a8,8,0,0,0,11.32,11.32L88.4,178.91A8,8,0,0,0,77.09,167.6ZM72,128a8,8,0,0,0-8-8H32a8,8,0,0,0,0,16H64A8,8,0,0,0,72,128ZM65.78,54.46A8,8,0,0,0,54.46,65.78L77.09,88.4A8,8,0,0,0,88.4,77.09Z"></path>`, 1);
var root_4$7 = from_svg(`<path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm33.94,58.75,17-17a8,8,0,0,1,11.32,11.32l-17,17a8,8,0,0,1-11.31-11.31ZM48,136a8,8,0,0,1,0-16H72a8,8,0,0,1,0,16Zm46.06,37.25-17,17a8,8,0,0,1-11.32-11.32l17-17a8,8,0,0,1,11.31,11.31Zm0-79.19a8,8,0,0,1-11.31,0l-17-17A8,8,0,0,1,77.09,65.77l17,17A8,8,0,0,1,94.06,94.06ZM136,208a8,8,0,0,1-16,0V184a8,8,0,0,1,16,0Zm0-136a8,8,0,0,1-16,0V48a8,8,0,0,1,16,0Zm54.23,118.23a8,8,0,0,1-11.32,0l-17-17a8,8,0,0,1,11.31-11.31l17,17A8,8,0,0,1,190.23,190.23ZM208,136H184a8,8,0,0,1,0-16h24a8,8,0,0,1,0,16Z"></path>`);
var root_5$6 = from_svg(`<path d="M134,32V64a6,6,0,0,1-12,0V32a6,6,0,0,1,12,0Zm39.25,56.75A6,6,0,0,0,177.5,87l22.62-22.63a6,6,0,0,0-8.48-8.48L169,78.5a6,6,0,0,0,4.24,10.25ZM224,122H192a6,6,0,0,0,0,12h32a6,6,0,0,0,0-12Zm-46.5,47A6,6,0,0,0,169,177.5l22.63,22.62a6,6,0,0,0,8.48-8.48ZM128,186a6,6,0,0,0-6,6v32a6,6,0,0,0,12,0V192A6,6,0,0,0,128,186ZM78.5,169,55.88,191.64a6,6,0,1,0,8.48,8.48L87,177.5A6,6,0,1,0,78.5,169ZM70,128a6,6,0,0,0-6-6H32a6,6,0,0,0,0,12H64A6,6,0,0,0,70,128ZM64.36,55.88a6,6,0,0,0-8.48,8.48L78.5,87A6,6,0,1,0,87,78.5Z"></path>`);
var root_6$7 = from_svg(`<path d="M136,32V64a8,8,0,0,1-16,0V32a8,8,0,0,1,16,0Zm37.25,58.75a8,8,0,0,0,5.66-2.35l22.63-22.62a8,8,0,0,0-11.32-11.32L167.6,77.09a8,8,0,0,0,5.65,13.66ZM224,120H192a8,8,0,0,0,0,16h32a8,8,0,0,0,0-16Zm-45.09,47.6a8,8,0,0,0-11.31,11.31l22.62,22.63a8,8,0,0,0,11.32-11.32ZM128,184a8,8,0,0,0-8,8v32a8,8,0,0,0,16,0V192A8,8,0,0,0,128,184ZM77.09,167.6,54.46,190.22a8,8,0,0,0,11.32,11.32L88.4,178.91A8,8,0,0,0,77.09,167.6ZM72,128a8,8,0,0,0-8-8H32a8,8,0,0,0,0,16H64A8,8,0,0,0,72,128ZM65.78,54.46A8,8,0,0,0,54.46,65.78L77.09,88.4A8,8,0,0,0,88.4,77.09Z"></path>`);
var root_7$7 = from_svg(`<path d="M132,32V64a4,4,0,0,1-8,0V32a4,4,0,0,1,8,0Zm41.25,54.75a4,4,0,0,0,2.83-1.18L198.71,63a4,4,0,0,0-5.66-5.66L170.43,79.92a4,4,0,0,0,2.82,6.83ZM224,124H192a4,4,0,0,0,0,8h32a4,4,0,0,0,0-8Zm-47.92,46.43a4,4,0,1,0-5.65,5.65l22.62,22.63a4,4,0,0,0,5.66-5.66ZM128,188a4,4,0,0,0-4,4v32a4,4,0,0,0,8,0V192A4,4,0,0,0,128,188ZM79.92,170.43,57.29,193.05A4,4,0,0,0,63,198.71l22.62-22.63a4,4,0,1,0-5.65-5.65ZM68,128a4,4,0,0,0-4-4H32a4,4,0,0,0,0,8H64A4,4,0,0,0,68,128ZM63,57.29A4,4,0,0,0,57.29,63L79.92,85.57a4,4,0,1,0,5.65-5.65Z"></path>`);
var root$14 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function Spinner($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root$14();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2$10());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3$7();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4$7());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$6());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6$7());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7$7());
	};
	var alternate = ($$anchor) => {
		var text$8 = text();
		text$8.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$8);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region node_modules/svelte-sonner/dist/Loader.svelte
var bars = Array(12).fill(0);
var root_1$1 = from_html(`<div class="sonner-loading-bar"></div>`);
var root$13 = from_html(`<div><div class="sonner-spinner"></div></div>`);
function Loader($$anchor, $$props) {
	push($$props, true);
	var div = root$13();
	var div_1 = child(div);
	each(div_1, 23, () => bars, (_, i) => `spinner-bar-${i}`, ($$anchor, _) => {
		append($$anchor, root_1$1());
	});
	reset(div_1);
	reset(div);
	template_effect(($0) => {
		set_class(div, 1, $0);
		set_attribute(div, "data-visible", $$props.visible);
	}, [() => clsx$1(["sonner-loading-wrapper", $$props.class].filter(Boolean).join(" "))]);
	append($$anchor, div);
	pop();
}
//#endregion
//#region node_modules/svelte-sonner/dist/internal/helpers.js
function cn(...classes) {
	return classes.filter(Boolean).join(" ");
}
var isBrowser = typeof document !== "undefined";
//#endregion
//#region node_modules/svelte-sonner/node_modules/runed/dist/internal/configurable-globals.js
var defaultWindow = typeof window !== "undefined" ? window : void 0;
typeof window !== "undefined" && window.document;
typeof window !== "undefined" && window.navigator;
typeof window !== "undefined" && window.location;
//#endregion
//#region node_modules/svelte-sonner/node_modules/runed/dist/internal/utils/dom.js
/**
* Handles getting the active element in a document or shadow root.
* If the active element is within a shadow root, it will traverse the shadow root
* to find the active element.
* If not, it will return the active element in the document.
*
* @param document A document or shadow root to get the active element from.
* @returns The active element in the document or shadow root.
*/
function getActiveElement(document) {
	let activeElement = document.activeElement;
	while (activeElement?.shadowRoot) {
		const node = activeElement.shadowRoot.activeElement;
		if (node === activeElement) break;
		else activeElement = node;
	}
	return activeElement;
}
//#endregion
//#region node_modules/svelte-sonner/node_modules/runed/dist/utilities/active-element/active-element.svelte.js
var ActiveElement = class {
	#document;
	#subscribe;
	constructor(options = {}) {
		const { window = defaultWindow, document = window?.document } = options;
		if (window === void 0) return;
		this.#document = document;
		this.#subscribe = createSubscriber((update) => {
			const cleanupFocusIn = on(window, "focusin", update);
			const cleanupFocusOut = on(window, "focusout", update);
			return () => {
				cleanupFocusIn();
				cleanupFocusOut();
			};
		});
	}
	get current() {
		this.#subscribe?.();
		if (!this.#document) return null;
		return getActiveElement(this.#document);
	}
};
new ActiveElement();
//#endregion
//#region node_modules/svelte-sonner/node_modules/runed/dist/utilities/context/context.js
var Context = class {
	#name;
	#key;
	/**
	* @param name The name of the context.
	* This is used for generating the context key and error messages.
	*/
	constructor(name) {
		this.#name = name;
		this.#key = Symbol(name);
	}
	/**
	* The key used to get and set the context.
	*
	* It is not recommended to use this value directly.
	* Instead, use the methods provided by this class.
	*/
	get key() {
		return this.#key;
	}
	/**
	* Checks whether this has been set in the context of a parent component.
	*
	* Must be called during component initialisation.
	*/
	exists() {
		return hasContext(this.#key);
	}
	/**
	* Retrieves the context that belongs to the closest parent component.
	*
	* Must be called during component initialisation.
	*
	* @throws An error if the context does not exist.
	*/
	get() {
		const context = getContext(this.#key);
		if (context === void 0) throw new Error(`Context "${this.#name}" not found`);
		return context;
	}
	/**
	* Retrieves the context that belongs to the closest parent component,
	* or the given fallback value if the context does not exist.
	*
	* Must be called during component initialisation.
	*/
	getOr(fallback) {
		const context = getContext(this.#key);
		if (context === void 0) return fallback;
		return context;
	}
	/**
	* Associates the given value with the current component and returns it.
	*
	* Must be called during component initialisation.
	*/
	set(context) {
		return setContext(this.#key, context);
	}
};
//#endregion
//#region node_modules/svelte-sonner/node_modules/runed/dist/utilities/watch/watch.svelte.js
function runEffect(flush, effect) {
	switch (flush) {
		case "post":
			user_effect(effect);
			break;
		case "pre":
			user_pre_effect(effect);
			break;
	}
}
function runWatcher(sources, flush, effect, options = {}) {
	const { lazy = false } = options;
	let active = !lazy;
	let previousValues = Array.isArray(sources) ? [] : void 0;
	runEffect(flush, () => {
		const values = Array.isArray(sources) ? sources.map((source) => source()) : sources();
		if (!active) {
			active = true;
			previousValues = values;
			return;
		}
		const cleanup = untrack(() => effect(values, previousValues));
		previousValues = values;
		return cleanup;
	});
}
function runWatcherOnce(sources, flush, effect) {
	const cleanupRoot = effect_root(() => {
		let stop = false;
		runWatcher(sources, flush, (values, previousValues) => {
			if (stop) {
				cleanupRoot();
				return;
			}
			const cleanup = effect(values, previousValues);
			stop = true;
			return cleanup;
		}, { lazy: true });
	});
	user_effect(() => {
		return cleanupRoot;
	});
}
function watch(sources, effect, options) {
	runWatcher(sources, "post", effect, options);
}
function watchPre(sources, effect, options) {
	runWatcher(sources, "pre", effect, options);
}
watch.pre = watchPre;
function watchOnce(source, effect) {
	runWatcherOnce(source, "post", effect);
}
function watchOncePre(source, effect) {
	runWatcherOnce(source, "pre", effect);
}
watchOnce.pre = watchOncePre;
//#endregion
//#region node_modules/svelte-sonner/node_modules/runed/dist/utilities/resource/resource.svelte.js
function debounce(fn, delay) {
	let timeoutId;
	let lastResolve = null;
	return (...args) => {
		return new Promise((resolve) => {
			if (lastResolve) lastResolve(void 0);
			lastResolve = resolve;
			clearTimeout(timeoutId);
			timeoutId = setTimeout(async () => {
				const result = await fn(...args);
				if (lastResolve) {
					lastResolve(result);
					lastResolve = null;
				}
			}, delay);
		});
	};
}
function throttle(fn, delay) {
	let lastRun = 0;
	let lastPromise = null;
	return (...args) => {
		const now = Date.now();
		if (lastRun && now - lastRun < delay) return lastPromise ?? Promise.resolve(void 0);
		lastRun = now;
		lastPromise = fn(...args);
		return lastPromise;
	};
}
function runResource(source, fetcher, options = {}, effectFn) {
	const { lazy = false, once = false, initialValue, debounce: debounceTime, throttle: throttleTime } = options;
	let current = state$1(proxy(initialValue));
	let loading = state$1(false);
	let error = state$1(void 0);
	let cleanupFns = state$1(proxy([]));
	const runCleanup = () => {
		get$2(cleanupFns).forEach((fn) => fn());
		set(cleanupFns, [], true);
	};
	const onCleanup = (fn) => {
		set(cleanupFns, [...get$2(cleanupFns), fn], true);
	};
	const baseFetcher = async (value, previousValue, refetching = false) => {
		try {
			set(loading, true);
			set(error, void 0);
			runCleanup();
			const controller = new AbortController();
			onCleanup(() => controller.abort());
			const result = await fetcher(value, previousValue, {
				data: get$2(current),
				refetching,
				onCleanup,
				signal: controller.signal
			});
			set(current, result, true);
			return result;
		} catch (e) {
			if (!(e instanceof DOMException && e.name === "AbortError")) set(error, e, true);
			return;
		} finally {
			set(loading, false);
		}
	};
	const runFetcher = debounceTime ? debounce(baseFetcher, debounceTime) : throttleTime ? throttle(baseFetcher, throttleTime) : baseFetcher;
	const sources = Array.isArray(source) ? source : [source];
	let prevValues;
	effectFn((values, previousValues) => {
		if (once && prevValues) return;
		prevValues = values;
		runFetcher(Array.isArray(source) ? values : values[0], Array.isArray(source) ? previousValues : previousValues?.[0]);
	}, { lazy });
	return {
		get current() {
			return get$2(current);
		},
		get loading() {
			return get$2(loading);
		},
		get error() {
			return get$2(error);
		},
		mutate: (value) => {
			set(current, value, true);
		},
		refetch: (info) => {
			const values = sources.map((s) => s());
			return runFetcher(Array.isArray(source) ? values : values[0], Array.isArray(source) ? values : values[0], info ?? true);
		}
	};
}
function resource(source, fetcher, options) {
	return runResource(source, fetcher, options, (fn, options) => {
		const sources = Array.isArray(source) ? source : [source];
		const getters = () => sources.map((s) => s());
		watch(getters, (values, previousValues) => {
			fn(values, previousValues ?? []);
		}, options);
	});
}
function resourcePre(source, fetcher, options) {
	return runResource(source, fetcher, options, (fn, options) => {
		const sources = Array.isArray(source) ? source : [source];
		const getter = () => sources.map((s) => s());
		watch.pre(getter, (values, previousValues) => {
			fn(values, previousValues ?? []);
		}, options);
	});
}
resource.pre = resourcePre;
new Context("richColorsContext");
var sonnerContext = new Context("<Toaster/>");
//#endregion
//#region node_modules/svelte-sonner/dist/toast-state.svelte.js
var toastsCounter = 0;
var ToastState = class {
	#toasts = state$1(proxy([]));
	get toasts() {
		return get$2(this.#toasts);
	}
	set toasts(value) {
		set(this.#toasts, value, true);
	}
	#heights = state$1(proxy([]));
	get heights() {
		return get$2(this.#heights);
	}
	set heights(value) {
		set(this.#heights, value, true);
	}
	#findToastIdx = (id) => {
		const idx = this.toasts.findIndex((toast) => toast.id === id);
		if (idx === -1) return null;
		return idx;
	};
	addToast = (data) => {
		if (!isBrowser) return;
		this.toasts.unshift(data);
	};
	updateToast = ({ id, data, type, message }) => {
		const toastIdx = this.toasts.findIndex((toast) => toast.id === id);
		const toastToUpdate = this.toasts[toastIdx];
		this.toasts[toastIdx] = {
			...toastToUpdate,
			...data,
			id,
			title: message,
			type,
			updated: true
		};
	};
	create = (data) => {
		const { message, ...rest } = data;
		const id = typeof data?.id === "number" || data.id && data.id?.length > 0 ? data.id : toastsCounter++;
		const dismissible = data.dismissible !== void 0 ? data.dismissible : data.dismissable !== void 0 ? data.dismissable : true;
		const type = data.type === void 0 ? "default" : data.type;
		untrack(() => {
			if (this.toasts.find((toast) => toast.id === id)) this.updateToast({
				id,
				data,
				type,
				message,
				dismissible
			});
			else this.addToast({
				...rest,
				id,
				title: message,
				dismissible,
				type
			});
		});
		return id;
	};
	dismiss = (id) => {
		untrack(() => {
			if (id === void 0) {
				this.toasts = this.toasts.map((toast) => ({
					...toast,
					dismiss: true
				}));
				return;
			}
			const toastIdx = this.toasts.findIndex((toast) => toast.id === id);
			if (this.toasts[toastIdx]) this.toasts[toastIdx] = {
				...this.toasts[toastIdx],
				dismiss: true
			};
		});
		return id;
	};
	remove = (id) => {
		if (id === void 0) {
			this.toasts = [];
			return;
		}
		const toastIdx = this.#findToastIdx(id);
		if (toastIdx === null) return;
		this.toasts.splice(toastIdx, 1);
		return id;
	};
	message = (message, data) => {
		return this.create({
			...data,
			type: "default",
			message
		});
	};
	error = (message, data) => {
		return this.create({
			...data,
			type: "error",
			message
		});
	};
	success = (message, data) => {
		return this.create({
			...data,
			type: "success",
			message
		});
	};
	info = (message, data) => {
		return this.create({
			...data,
			type: "info",
			message
		});
	};
	warning = (message, data) => {
		return this.create({
			...data,
			type: "warning",
			message
		});
	};
	loading = (message, data) => {
		return this.create({
			...data,
			type: "loading",
			message
		});
	};
	promise = (promise, data) => {
		if (!data) return;
		let id = void 0;
		if (data.loading !== void 0) id = this.create({
			...data,
			promise,
			type: "loading",
			message: typeof data.loading === "string" ? data.loading : data.loading()
		});
		const p = promise instanceof Promise ? promise : promise();
		let shouldDismiss = id !== void 0;
		p.then((response) => {
			if (typeof response === "object" && response && "ok" in response && typeof response.ok === "boolean" && !response.ok) {
				shouldDismiss = false;
				const message = constructPromiseErrorMessage(response);
				this.create({
					id,
					type: "error",
					message
				});
			} else if (data.success !== void 0) {
				shouldDismiss = false;
				const message = typeof data.success === "function" ? data.success(response) : data.success;
				this.create({
					id,
					type: "success",
					message
				});
			}
		}).catch((error) => {
			if (data.error !== void 0) {
				shouldDismiss = false;
				const message = typeof data.error === "function" ? data.error(error) : data.error;
				this.create({
					id,
					type: "error",
					message
				});
			}
		}).finally(() => {
			if (shouldDismiss) {
				this.dismiss(id);
				id = void 0;
			}
			data.finally?.();
		});
		return id;
	};
	custom = (component, data) => {
		const id = data?.id || toastsCounter++;
		this.create({
			component,
			id,
			...data
		});
		return id;
	};
	removeHeight = (id) => {
		this.heights = this.heights.filter((height) => height.toastId !== id);
	};
	setHeight = (data) => {
		const toastIdx = this.#findToastIdx(data.toastId);
		if (toastIdx === null) {
			this.heights.push(data);
			return;
		}
		this.heights[toastIdx] = data;
	};
	reset = () => {
		this.toasts = [];
		this.heights = [];
	};
};
function constructPromiseErrorMessage(response) {
	if (response && typeof response === "object" && "status" in response) return `HTTP error! Status: ${response.status}`;
	return `Error! ${response}`;
}
var toastState = new ToastState();
function toastFunction(message, data) {
	return toastState.create({
		message,
		...data
	});
}
var SonnerState = class {
	/**
	* A derived state of the toasts that are not dismissed.
	*/
	#activeToasts = user_derived(() => toastState.toasts.filter((toast) => !toast.dismiss));
	get toasts() {
		return get$2(this.#activeToasts);
	}
};
var toast = Object.assign(toastFunction, {
	success: toastState.success,
	info: toastState.info,
	warning: toastState.warning,
	error: toastState.error,
	custom: toastState.custom,
	message: toastState.message,
	promise: toastState.promise,
	dismiss: toastState.dismiss,
	loading: toastState.loading,
	getActiveToasts: () => {
		return toastState.toasts.filter((toast) => !toast.dismiss);
	}
});
//#endregion
//#region node_modules/svelte-sonner/dist/types.js
function isAction(action) {
	return action.label !== void 0;
}
//#endregion
//#region node_modules/svelte-sonner/dist/internal/use-document-hidden.svelte.js
function useDocumentHidden() {
	let current = state$1(proxy(typeof document !== "undefined" ? document.hidden : false));
	user_effect(() => {
		return on(document, "visibilitychange", () => {
			set(current, document.hidden, true);
		});
	});
	return { get current() {
		return get$2(current);
	} };
}
//#endregion
//#region node_modules/svelte-sonner/dist/Toast.svelte
var TOAST_LIFETIME$1 = 4e3;
var GAP$1 = 14;
var SWIPE_THRESHOLD = 45;
var TIME_BEFORE_UNMOUNT = 200;
var SCALE_MULTIPLIER = .05;
var DEFAULT_TOAST_CLASSES = {
	toast: "",
	title: "",
	description: "",
	loader: "",
	closeButton: "",
	cancelButton: "",
	actionButton: "",
	action: "",
	warning: "",
	error: "",
	success: "",
	default: "",
	info: "",
	loading: ""
};
function getDefaultSwipeDirections(position) {
	const [y, x] = position.split("-");
	const directions = [];
	if (y) directions.push(y);
	if (x) directions.push(x);
	return directions;
}
function getDampening(delta) {
	return 1 / (1.5 + Math.abs(delta) / 20);
}
var root_2$9 = from_html(`<div><!></div>`);
var root_4$6 = from_html(`<button data-close-button=""><!></button>`);
var root_7$6 = from_html(`<div data-icon=""><!> <!></div>`);
var root_20 = from_html(`<div data-description=""><!></div>`);
var root_25 = from_html(`<button data-button="" data-cancel=""> </button>`);
var root_28 = from_html(`<button data-button=""> </button>`);
var root_6$6 = from_html(`<!> <div data-content=""><div data-title=""><!></div> <!></div> <!> <!>`, 1);
var root$12 = from_html(`<li aria-atomic="true" data-sonner-toast=""><!> <!></li>`);
function Toast($$anchor, $$props) {
	push($$props, true);
	const LoadingIcon = ($$anchor) => {
		var fragment = comment();
		var node = first_child(fragment);
		var consequent = ($$anchor) => {
			var div = root_2$9();
			snippet(child(div), () => $$props.loadingIcon);
			reset(div);
			template_effect(($0) => {
				set_class(div, 1, $0);
				set_attribute(div, "data-visible", get$2(toastType) === "loading");
			}, [() => clsx$1(cn(get$2(classes)?.loader, $$props.toast?.classes?.loader, "sonner-loader"))]);
			append($$anchor, div);
		};
		var alternate = ($$anchor) => {
			{
				let $0 = user_derived(() => cn(get$2(classes)?.loader, $$props.toast.classes?.loader));
				let $1 = user_derived(() => get$2(toastType) === "loading");
				Loader($$anchor, {
					get class() {
						return get$2($0);
					},
					get visible() {
						return get$2($1);
					}
				});
			}
		};
		if_block(node, ($$render) => {
			if ($$props.loadingIcon) $$render(consequent);
			else $$render(alternate, -1);
		});
		append($$anchor, fragment);
	};
	let cancelButtonStyle = prop($$props, "cancelButtonStyle", 3, ""), actionButtonStyle = prop($$props, "actionButtonStyle", 3, ""), descriptionClass = prop($$props, "descriptionClass", 3, ""), unstyled = prop($$props, "unstyled", 3, false), defaultRichColors = prop($$props, "defaultRichColors", 3, false);
	rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"toast",
		"index",
		"expanded",
		"invert",
		"position",
		"visibleToasts",
		"expandByDefault",
		"closeButton",
		"interacting",
		"cancelButtonStyle",
		"actionButtonStyle",
		"duration",
		"descriptionClass",
		"classes",
		"unstyled",
		"loadingIcon",
		"successIcon",
		"errorIcon",
		"warningIcon",
		"closeIcon",
		"infoIcon",
		"defaultRichColors",
		"swipeDirections",
		"closeButtonAriaLabel",
		"pauseWhenPageIsHidden"
	]);
	const defaultClasses = { ...DEFAULT_TOAST_CLASSES };
	let mounted = state$1(false);
	let removed = state$1(false);
	let swiping = state$1(false);
	let swipeOut = state$1(false);
	let isSwiped = state$1(false);
	let offsetBeforeRemove = state$1(0);
	let initialHeight = state$1(0);
	let remainingTime = $$props.toast.duration || $$props.duration || TOAST_LIFETIME$1;
	let dragStartTime = null;
	let toastRef = state$1(void 0);
	let swipeDirection = state$1(null);
	let swipeOutDirection = state$1(null);
	const isFront = user_derived(() => $$props.index === 0);
	const isVisible = user_derived(() => $$props.index + 1 <= $$props.visibleToasts);
	const toastType = user_derived(() => $$props.toast.type);
	const dismissible = user_derived(() => $$props.toast.dismissible !== void 0 ? $$props.toast.dismissible !== false : $$props.toast.dismissable !== false);
	const toastClass = user_derived(() => $$props.toast.class || "");
	const toastDescriptionClass = user_derived(() => $$props.toast.descriptionClass || "");
	const heightIndex = user_derived(() => toastState.heights.findIndex((height) => height.toastId === $$props.toast.id) || 0);
	const closeButton = user_derived(() => $$props.toast.closeButton ?? $$props.closeButton);
	const duration = user_derived(() => $$props.toast.duration ?? $$props.duration ?? TOAST_LIFETIME$1);
	let pointerStart = null;
	const coords = user_derived(() => $$props.position.split("-"));
	const toastsHeightBefore = user_derived(() => toastState.heights.reduce((prev, curr, reducerIndex) => {
		if (reducerIndex >= get$2(heightIndex)) return prev;
		return prev + curr.height;
	}, 0));
	const isDocumentHidden = useDocumentHidden();
	const invert = user_derived(() => $$props.toast.invert || $$props.invert);
	const disabled = user_derived(() => get$2(toastType) === "loading");
	const classes = user_derived(() => ({
		...defaultClasses,
		...$$props.classes
	}));
	const toastTitle = user_derived(() => $$props.toast.title);
	const toastDescription = user_derived(() => $$props.toast.description);
	let closeTimerStartTime = state$1(0);
	let lastCloseTimerStartTime = state$1(0);
	const offset = user_derived(() => Math.round(get$2(heightIndex) * GAP$1 + get$2(toastsHeightBefore)));
	user_effect(() => {
		get$2(toastTitle);
		get$2(toastDescription);
		let scale;
		if ($$props.expanded || $$props.expandByDefault) scale = 1;
		else scale = 1 - $$props.index * SCALE_MULTIPLIER;
		const toastEl = untrack(() => get$2(toastRef));
		if (toastEl === void 0) return;
		toastEl.style.setProperty("height", "auto");
		const offsetHeight = toastEl.offsetHeight;
		const rectHeight = toastEl.getBoundingClientRect().height;
		const scaledRectHeight = Math.round(rectHeight / scale + Number.EPSILON & 100) / 100;
		toastEl.style.removeProperty("height");
		let finalHeight;
		if (Math.abs(scaledRectHeight - offsetHeight) < 1) finalHeight = scaledRectHeight;
		else finalHeight = offsetHeight;
		set(initialHeight, finalHeight, true);
		toastState.setHeight({
			toastId: $$props.toast.id,
			height: finalHeight
		});
	});
	function deleteToast() {
		set(removed, true);
		set(offsetBeforeRemove, get$2(offset), true);
		toastState.removeHeight($$props.toast.id);
		setTimeout(() => {
			toastState.remove($$props.toast.id);
		}, TIME_BEFORE_UNMOUNT);
	}
	let timeoutId;
	const isPromiseLoadingOrInfiniteDuration = user_derived(() => $$props.toast.promise && get$2(toastType) === "loading" || $$props.toast.duration === Number.POSITIVE_INFINITY);
	function startTimer() {
		set(closeTimerStartTime, (/* @__PURE__ */ new Date()).getTime(), true);
		timeoutId = setTimeout(() => {
			$$props.toast.onAutoClose?.($$props.toast);
			deleteToast();
		}, remainingTime);
	}
	function pauseTimer() {
		if (get$2(lastCloseTimerStartTime) < get$2(closeTimerStartTime)) {
			const elapsedTime = (/* @__PURE__ */ new Date()).getTime() - get$2(closeTimerStartTime);
			remainingTime = remainingTime - elapsedTime;
		}
		set(lastCloseTimerStartTime, (/* @__PURE__ */ new Date()).getTime(), true);
	}
	user_effect(() => {
		if ($$props.toast.updated) {
			clearTimeout(timeoutId);
			remainingTime = get$2(duration);
			if (!get$2(isPromiseLoadingOrInfiniteDuration)) startTimer();
		}
	});
	user_effect(() => {
		if (!get$2(isPromiseLoadingOrInfiniteDuration)) if ($$props.expanded || $$props.interacting || $$props.pauseWhenPageIsHidden && isDocumentHidden.current) pauseTimer();
		else startTimer();
		return () => clearTimeout(timeoutId);
	});
	onMount(() => {
		set(mounted, true);
		const height = get$2(toastRef)?.getBoundingClientRect().height;
		set(initialHeight, height, true);
		toastState.setHeight({
			toastId: $$props.toast.id,
			height
		});
		return () => {
			toastState.removeHeight($$props.toast.id);
		};
	});
	user_effect(() => {
		if ($$props.toast.delete) untrack(() => {
			deleteToast();
			$$props.toast.onDismiss?.($$props.toast);
		});
	});
	const handlePointerDown = (event) => {
		if (get$2(disabled)) return;
		set(offsetBeforeRemove, get$2(offset), true);
		const target = event.target;
		target.setPointerCapture(event.pointerId);
		if (target.tagName === "BUTTON") return;
		set(swiping, true);
		pointerStart = {
			x: event.clientX,
			y: event.clientY
		};
	};
	const handlePointerUp = () => {
		if (get$2(swipeOut) || !get$2(dismissible)) return;
		pointerStart = null;
		const swipeAmountX = Number(get$2(toastRef)?.style.getPropertyValue("--swipe-amount-x").replace("px", "") || 0);
		const swipeAmountY = Number(get$2(toastRef)?.style.getPropertyValue("--swipe-amount-y").replace("px", "") || 0);
		const timeTaken = (/* @__PURE__ */ new Date()).getTime() - (dragStartTime?.getTime() ?? 0);
		const swipeAmount = get$2(swipeDirection) === "x" ? swipeAmountX : swipeAmountY;
		const velocity = Math.abs(swipeAmount) / timeTaken;
		if (Math.abs(swipeAmount) >= SWIPE_THRESHOLD || velocity > .11) {
			set(offsetBeforeRemove, get$2(offset), true);
			$$props.toast.onDismiss?.($$props.toast);
			if (get$2(swipeDirection) === "x") set(swipeOutDirection, swipeAmountX > 0 ? "right" : "left", true);
			else set(swipeOutDirection, swipeAmountY > 0 ? "down" : "up", true);
			deleteToast();
			set(swipeOut, true);
			return;
		} else {
			get$2(toastRef)?.style.setProperty("--swipe-amount-x", "0px");
			get$2(toastRef)?.style.setProperty("--swipe-amount-y", "0px");
		}
		set(isSwiped, false);
		set(swiping, false);
		set(swipeDirection, null);
	};
	const handlePointerMove = (event) => {
		if (!pointerStart || !get$2(dismissible)) return;
		if ((window.getSelection()?.toString().length ?? -1) > 0) return;
		const yDelta = event.clientY - pointerStart.y;
		const xDelta = event.clientX - pointerStart.x;
		const swipeDirections = $$props.swipeDirections ?? getDefaultSwipeDirections($$props.position);
		if (!get$2(swipeDirection) && (Math.abs(xDelta) > 1 || Math.abs(yDelta) > 1)) set(swipeDirection, Math.abs(xDelta) > Math.abs(yDelta) ? "x" : "y", true);
		let swipeAmount = {
			x: 0,
			y: 0
		};
		if (get$2(swipeDirection) === "y") {
			if (swipeDirections.includes("top") || swipeDirections.includes("bottom")) if (swipeDirections.includes("top") && yDelta < 0 || swipeDirections.includes("bottom") && yDelta > 0) swipeAmount.y = yDelta;
			else {
				const dampenedDelta = yDelta * getDampening(yDelta);
				swipeAmount.y = Math.abs(dampenedDelta) < Math.abs(yDelta) ? dampenedDelta : yDelta;
			}
		} else if (get$2(swipeDirection) === "x") {
			if (swipeDirections.includes("left") || swipeDirections.includes("right")) if (swipeDirections.includes("left") && xDelta < 0 || swipeDirections.includes("right") && xDelta > 0) swipeAmount.x = xDelta;
			else {
				const dampenedDelta = xDelta * getDampening(xDelta);
				swipeAmount.x = Math.abs(dampenedDelta) < Math.abs(xDelta) ? dampenedDelta : xDelta;
			}
		}
		if (Math.abs(swipeAmount.x) > 0 || Math.abs(swipeAmount.y) > 0) set(isSwiped, true);
		get$2(toastRef)?.style.setProperty("--swipe-amount-x", `${swipeAmount.x}px`);
		get$2(toastRef)?.style.setProperty("--swipe-amount-y", `${swipeAmount.y}px`);
	};
	const handleDragEnd = () => {
		set(swiping, false);
		set(swipeDirection, null);
		pointerStart = null;
	};
	const icon = user_derived(() => {
		if ($$props.toast.icon) return $$props.toast.icon;
		if (get$2(toastType) === "success") return $$props.successIcon;
		if (get$2(toastType) === "error") return $$props.errorIcon;
		if (get$2(toastType) === "warning") return $$props.warningIcon;
		if (get$2(toastType) === "info") return $$props.infoIcon;
		if (get$2(toastType) === "loading") return $$props.loadingIcon;
		return null;
	});
	var li = root$12();
	set_attribute(li, "tabindex", 0);
	let styles;
	var node_2 = child(li);
	var consequent_1 = ($$anchor) => {
		var button = root_4$6();
		snippet(child(button), () => $$props.closeIcon ?? noop$1);
		reset(button);
		template_effect(($0) => {
			set_attribute(button, "aria-label", $$props.closeButtonAriaLabel);
			set_attribute(button, "data-disabled", get$2(disabled));
			set_class(button, 1, $0);
		}, [() => clsx$1(cn(get$2(classes)?.closeButton, $$props.toast?.classes?.closeButton))]);
		delegated("click", button, () => {
			if (get$2(disabled) || !get$2(dismissible)) return;
			deleteToast();
			$$props.toast.onDismiss?.($$props.toast);
		});
		append($$anchor, button);
	};
	if_block(node_2, ($$render) => {
		if (get$2(closeButton) && !$$props.toast.component && get$2(toastType) !== "loading" && $$props.closeIcon !== null) $$render(consequent_1);
	});
	var node_4 = sibling(node_2, 2);
	var consequent_2 = ($$anchor) => {
		const Component = user_derived(() => $$props.toast.component);
		var fragment_2 = comment();
		component(first_child(fragment_2), () => get$2(Component), ($$anchor, Component_1) => {
			Component_1($$anchor, spread_props(() => $$props.toast.componentProps, { closeToast: deleteToast }));
		});
		append($$anchor, fragment_2);
	};
	var alternate_4 = ($$anchor) => {
		var fragment_3 = root_6$6();
		var node_6 = first_child(fragment_3);
		var consequent_11 = ($$anchor) => {
			var div_1 = root_7$6();
			var node_7 = child(div_1);
			var consequent_4 = ($$anchor) => {
				var fragment_4 = comment();
				var node_8 = first_child(fragment_4);
				var consequent_3 = ($$anchor) => {
					var fragment_5 = comment();
					component(first_child(fragment_5), () => $$props.toast.icon, ($$anchor, toast_icon) => {
						toast_icon($$anchor, {});
					});
					append($$anchor, fragment_5);
				};
				var alternate_1 = ($$anchor) => {
					LoadingIcon($$anchor);
				};
				if_block(node_8, ($$render) => {
					if ($$props.toast.icon) $$render(consequent_3);
					else $$render(alternate_1, -1);
				});
				append($$anchor, fragment_4);
			};
			if_block(node_7, ($$render) => {
				if ($$props.toast.promise || get$2(toastType) === "loading") $$render(consequent_4);
			});
			var node_10 = sibling(node_7, 2);
			var consequent_10 = ($$anchor) => {
				var fragment_7 = comment();
				var node_11 = first_child(fragment_7);
				var consequent_5 = ($$anchor) => {
					var fragment_8 = comment();
					component(first_child(fragment_8), () => $$props.toast.icon, ($$anchor, toast_icon_1) => {
						toast_icon_1($$anchor, {});
					});
					append($$anchor, fragment_8);
				};
				var consequent_6 = ($$anchor) => {
					var fragment_9 = comment();
					snippet(first_child(fragment_9), () => $$props.successIcon ?? noop$1);
					append($$anchor, fragment_9);
				};
				var consequent_7 = ($$anchor) => {
					var fragment_10 = comment();
					snippet(first_child(fragment_10), () => $$props.errorIcon ?? noop$1);
					append($$anchor, fragment_10);
				};
				var consequent_8 = ($$anchor) => {
					var fragment_11 = comment();
					snippet(first_child(fragment_11), () => $$props.warningIcon ?? noop$1);
					append($$anchor, fragment_11);
				};
				var consequent_9 = ($$anchor) => {
					var fragment_12 = comment();
					snippet(first_child(fragment_12), () => $$props.infoIcon ?? noop$1);
					append($$anchor, fragment_12);
				};
				if_block(node_11, ($$render) => {
					if ($$props.toast.icon) $$render(consequent_5);
					else if (get$2(toastType) === "success") $$render(consequent_6, 1);
					else if (get$2(toastType) === "error") $$render(consequent_7, 2);
					else if (get$2(toastType) === "warning") $$render(consequent_8, 3);
					else if (get$2(toastType) === "info") $$render(consequent_9, 4);
				});
				append($$anchor, fragment_7);
			};
			if_block(node_10, ($$render) => {
				if ($$props.toast.type !== "loading") $$render(consequent_10);
			});
			reset(div_1);
			template_effect(($0) => set_class(div_1, 1, $0), [() => clsx$1(cn(get$2(classes)?.icon, $$props.toast?.classes?.icon))]);
			append($$anchor, div_1);
		};
		if_block(node_6, ($$render) => {
			if ((get$2(toastType) || $$props.toast.icon || $$props.toast.promise) && $$props.toast.icon !== null && (get$2(icon) !== null || $$props.toast.icon)) $$render(consequent_11);
		});
		var div_2 = sibling(node_6, 2);
		var div_3 = child(div_2);
		var node_17 = child(div_3);
		var consequent_13 = ($$anchor) => {
			var fragment_13 = comment();
			var node_18 = first_child(fragment_13);
			var consequent_12 = ($$anchor) => {
				const Title = user_derived(() => $$props.toast.title);
				var fragment_14 = comment();
				component(first_child(fragment_14), () => get$2(Title), ($$anchor, Title_1) => {
					Title_1($$anchor, spread_props(() => $$props.toast.componentProps));
				});
				append($$anchor, fragment_14);
			};
			var alternate_2 = ($$anchor) => {
				var text$7 = text();
				template_effect(() => set_text(text$7, $$props.toast.title));
				append($$anchor, text$7);
			};
			if_block(node_18, ($$render) => {
				if (typeof $$props.toast.title !== "string") $$render(consequent_12);
				else $$render(alternate_2, -1);
			});
			append($$anchor, fragment_13);
		};
		if_block(node_17, ($$render) => {
			if ($$props.toast.title) $$render(consequent_13);
		});
		reset(div_3);
		var node_20 = sibling(div_3, 2);
		var consequent_15 = ($$anchor) => {
			var div_4 = root_20();
			var node_21 = child(div_4);
			var consequent_14 = ($$anchor) => {
				const Description = user_derived(() => $$props.toast.description);
				var fragment_16 = comment();
				component(first_child(fragment_16), () => get$2(Description), ($$anchor, Description_1) => {
					Description_1($$anchor, spread_props(() => $$props.toast.componentProps));
				});
				append($$anchor, fragment_16);
			};
			var alternate_3 = ($$anchor) => {
				var text_1 = text();
				template_effect(() => set_text(text_1, $$props.toast.description));
				append($$anchor, text_1);
			};
			if_block(node_21, ($$render) => {
				if (typeof $$props.toast.description !== "string") $$render(consequent_14);
				else $$render(alternate_3, -1);
			});
			reset(div_4);
			template_effect(($0) => set_class(div_4, 1, $0), [() => clsx$1(cn(descriptionClass(), get$2(toastDescriptionClass), get$2(classes)?.description, $$props.toast.classes?.description))]);
			append($$anchor, div_4);
		};
		if_block(node_20, ($$render) => {
			if ($$props.toast.description) $$render(consequent_15);
		});
		reset(div_2);
		var node_23 = sibling(div_2, 2);
		var consequent_18 = ($$anchor) => {
			var fragment_18 = comment();
			var node_24 = first_child(fragment_18);
			var consequent_16 = ($$anchor) => {
				var fragment_19 = comment();
				component(first_child(fragment_19), () => $$props.toast.cancel, ($$anchor, toast_cancel) => {
					toast_cancel($$anchor, {});
				});
				append($$anchor, fragment_19);
			};
			var consequent_17 = ($$anchor) => {
				var button_1 = root_25();
				var text_2 = child(button_1, true);
				reset(button_1);
				template_effect(($0) => {
					set_style(button_1, $$props.toast.cancelButtonStyle ?? cancelButtonStyle());
					set_class(button_1, 1, $0);
					set_text(text_2, $$props.toast.cancel.label);
				}, [() => clsx$1(cn(get$2(classes)?.cancelButton, $$props.toast?.classes?.cancelButton))]);
				delegated("click", button_1, (event) => {
					if (!isAction($$props.toast.cancel)) return;
					if (!get$2(dismissible)) return;
					$$props.toast.cancel?.onClick?.(event);
					deleteToast();
				});
				append($$anchor, button_1);
			};
			var d = user_derived(() => isAction($$props.toast.cancel));
			if_block(node_24, ($$render) => {
				if (typeof $$props.toast.cancel === "function") $$render(consequent_16);
				else if (get$2(d)) $$render(consequent_17, 1);
			});
			append($$anchor, fragment_18);
		};
		if_block(node_23, ($$render) => {
			if ($$props.toast.cancel) $$render(consequent_18);
		});
		var node_26 = sibling(node_23, 2);
		var consequent_21 = ($$anchor) => {
			var fragment_20 = comment();
			var node_27 = first_child(fragment_20);
			var consequent_19 = ($$anchor) => {
				var fragment_21 = comment();
				component(first_child(fragment_21), () => $$props.toast.action, ($$anchor, toast_action) => {
					toast_action($$anchor, {});
				});
				append($$anchor, fragment_21);
			};
			var consequent_20 = ($$anchor) => {
				var button_2 = root_28();
				var text_3 = child(button_2, true);
				reset(button_2);
				template_effect(($0) => {
					set_style(button_2, $$props.toast.actionButtonStyle ?? actionButtonStyle());
					set_class(button_2, 1, $0);
					set_text(text_3, $$props.toast.action.label);
				}, [() => clsx$1(cn(get$2(classes)?.actionButton, $$props.toast?.classes?.actionButton))]);
				delegated("click", button_2, (event) => {
					if (!isAction($$props.toast.action)) return;
					$$props.toast.action?.onClick(event);
					if (event.defaultPrevented) return;
					deleteToast();
				});
				append($$anchor, button_2);
			};
			var d_1 = user_derived(() => isAction($$props.toast.action));
			if_block(node_27, ($$render) => {
				if (typeof $$props.toast.action === "function") $$render(consequent_19);
				else if (get$2(d_1)) $$render(consequent_20, 1);
			});
			append($$anchor, fragment_20);
		};
		if_block(node_26, ($$render) => {
			if ($$props.toast.action) $$render(consequent_21);
		});
		template_effect(($0, $1) => {
			set_class(div_2, 1, $0);
			set_class(div_3, 1, $1);
		}, [() => clsx$1(cn(get$2(classes)?.content, $$props.toast?.classes?.content)), () => clsx$1(cn(get$2(classes)?.title, $$props.toast?.classes?.title))]);
		append($$anchor, fragment_3);
	};
	if_block(node_4, ($$render) => {
		if ($$props.toast.component) $$render(consequent_2);
		else $$render(alternate_4, -1);
	});
	reset(li);
	bind_this(li, ($$value) => set(toastRef, $$value), () => get$2(toastRef));
	template_effect(($0, $1, $2) => {
		set_class(li, 1, $0);
		set_attribute(li, "aria-live", $$props.toast.important ? "assertive" : "polite");
		set_attribute(li, "data-rich-colors", $$props.toast.richColors ?? defaultRichColors());
		set_attribute(li, "data-styled", !($$props.toast.component || $$props.toast.unstyled || unstyled()));
		set_attribute(li, "data-mounted", get$2(mounted));
		set_attribute(li, "data-promise", $1);
		set_attribute(li, "data-swiped", get$2(isSwiped));
		set_attribute(li, "data-removed", get$2(removed));
		set_attribute(li, "data-visible", get$2(isVisible));
		set_attribute(li, "data-y-position", get$2(coords)[0]);
		set_attribute(li, "data-x-position", get$2(coords)[1]);
		set_attribute(li, "data-index", $$props.index);
		set_attribute(li, "data-front", get$2(isFront));
		set_attribute(li, "data-swiping", get$2(swiping));
		set_attribute(li, "data-dismissible", get$2(dismissible));
		set_attribute(li, "data-type", get$2(toastType));
		set_attribute(li, "data-invert", get$2(invert));
		set_attribute(li, "data-swipe-out", get$2(swipeOut));
		set_attribute(li, "data-swipe-direction", get$2(swipeOutDirection));
		set_attribute(li, "data-expanded", $2);
		styles = set_style(li, `${$$props.style} ${$$props.toast.style}`, styles, {
			"--index": $$props.index,
			"--toasts-before": $$props.index,
			"--z-index": toastState.toasts.length - $$props.index,
			"--offset": `${get$2(removed) ? get$2(offsetBeforeRemove) : get$2(offset)}px`,
			"--initial-height": $$props.expandByDefault ? "auto" : `${get$2(initialHeight)}px`
		});
	}, [
		() => clsx$1(cn($$props.class, get$2(toastClass), get$2(classes)?.toast, $$props.toast?.classes?.toast, get$2(classes)?.[get$2(toastType)], $$props.toast?.classes?.[get$2(toastType)])),
		() => Boolean($$props.toast.promise),
		() => Boolean($$props.expanded || $$props.expandByDefault && get$2(mounted))
	]);
	delegated("pointermove", li, handlePointerMove);
	delegated("pointerup", li, handlePointerUp);
	delegated("pointerdown", li, handlePointerDown);
	event("dragend", li, handleDragEnd);
	append($$anchor, li);
	pop();
}
delegate([
	"pointermove",
	"pointerup",
	"pointerdown",
	"click"
]);
//#endregion
//#region node_modules/svelte-sonner/dist/icons/SuccessIcon.svelte
var root$11 = from_svg(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" height="20" width="20" data-sonner-success-icon=""><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd"></path></svg>`);
function SuccessIcon($$anchor) {
	append($$anchor, root$11());
}
//#endregion
//#region node_modules/svelte-sonner/dist/icons/ErrorIcon.svelte
var root$10 = from_svg(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" height="20" width="20" data-sonner-error-icon=""><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-5a.75.75 0 01.75.75v4.5a.75.75 0 01-1.5 0v-4.5A.75.75 0 0110 5zm0 10a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>`);
function ErrorIcon($$anchor) {
	append($$anchor, root$10());
}
//#endregion
//#region node_modules/svelte-sonner/dist/icons/WarningIcon.svelte
var root$9 = from_svg(`<svg viewBox="0 0 64 64" fill="currentColor" height="20" width="20" data-sonner-warning-icon="" xmlns="http://www.w3.org/2000/svg"><path d="M32.427,7.987c2.183,0.124 4,1.165 5.096,3.281l17.936,36.208c1.739,3.66 -0.954,8.585 -5.373,8.656l-36.119,0c-4.022,-0.064 -7.322,-4.631 -5.352,-8.696l18.271,-36.207c0.342,-0.65 0.498,-0.838 0.793,-1.179c1.186,-1.375 2.483,-2.111 4.748,-2.063Zm-0.295,3.997c-0.687,0.034 -1.316,0.419 -1.659,1.017c-6.312,11.979 -12.397,24.081 -18.301,36.267c-0.546,1.225 0.391,2.797 1.762,2.863c12.06,0.195 24.125,0.195 36.185,0c1.325,-0.064 2.321,-1.584 1.769,-2.85c-5.793,-12.184 -11.765,-24.286 -17.966,-36.267c-0.366,-0.651 -0.903,-1.042 -1.79,-1.03Z"></path><path d="M33.631,40.581l-3.348,0l-0.368,-16.449l4.1,0l-0.384,16.449Zm-3.828,5.03c0,-0.609 0.197,-1.113 0.592,-1.514c0.396,-0.4 0.935,-0.601 1.618,-0.601c0.684,0 1.223,0.201 1.618,0.601c0.395,0.401 0.593,0.905 0.593,1.514c0,0.587 -0.193,1.078 -0.577,1.473c-0.385,0.395 -0.929,0.593 -1.634,0.593c-0.705,0 -1.249,-0.198 -1.634,-0.593c-0.384,-0.395 -0.576,-0.886 -0.576,-1.473Z"></path></svg>`);
function WarningIcon($$anchor) {
	append($$anchor, root$9());
}
//#endregion
//#region node_modules/svelte-sonner/dist/icons/InfoIcon.svelte
var root$8 = from_svg(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" height="20" width="20" data-sonner-info-icon=""><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd"></path></svg>`);
function InfoIcon($$anchor) {
	append($$anchor, root$8());
}
//#endregion
//#region node_modules/svelte-sonner/dist/icons/CloseIcon.svelte
var root$7 = from_svg(`<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-sonner-close-icon=""><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>`);
function CloseIcon($$anchor) {
	append($$anchor, root$7());
}
//#endregion
//#region node_modules/svelte-sonner/dist/Toaster.svelte
var VISIBLE_TOASTS_AMOUNT = 3;
var VIEWPORT_OFFSET = "24px";
var MOBILE_VIEWPORT_OFFSET = "16px";
var TOAST_LIFETIME = 4e3;
var TOAST_WIDTH = 356;
var GAP = 14;
var DARK = "dark";
var LIGHT = "light";
function getOffsetObject(defaultOffset, mobileOffset) {
	const styles = {};
	[defaultOffset, mobileOffset].forEach((offset, index) => {
		const isMobile = index === 1;
		const prefix = isMobile ? "--mobile-offset" : "--offset";
		const defaultValue = isMobile ? MOBILE_VIEWPORT_OFFSET : VIEWPORT_OFFSET;
		function assignAll(offset) {
			[
				"top",
				"right",
				"bottom",
				"left"
			].forEach((key) => {
				styles[`${prefix}-${key}`] = typeof offset === "number" ? `${offset}px` : offset;
			});
		}
		if (typeof offset === "number" || typeof offset === "string") assignAll(offset);
		else if (typeof offset === "object") [
			"top",
			"right",
			"bottom",
			"left"
		].forEach((key) => {
			const value = offset[key];
			if (value === void 0) styles[`${prefix}-${key}`] = defaultValue;
			else styles[`${prefix}-${key}`] = typeof value === "number" ? `${value}px` : value;
		});
		else assignAll(defaultValue);
	});
	return styles;
}
var root_2$8 = from_html(`<ol></ol>`);
var root$6 = from_html(`<section aria-live="polite" aria-relevant="additions text" aria-atomic="false" class="svelte-nbs0zk"><!></section>`);
function Toaster($$anchor, $$props) {
	push($$props, true);
	function getInitialTheme(t) {
		if (t !== "system") return t;
		if (typeof window !== "undefined") {
			if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) return DARK;
			return LIGHT;
		}
		return LIGHT;
	}
	let invert = prop($$props, "invert", 3, false), position = prop($$props, "position", 3, "bottom-right"), hotkey = prop($$props, "hotkey", 19, () => ["altKey", "KeyT"]), expand = prop($$props, "expand", 3, false), closeButton = prop($$props, "closeButton", 3, false), offset = prop($$props, "offset", 3, VIEWPORT_OFFSET), mobileOffset = prop($$props, "mobileOffset", 3, MOBILE_VIEWPORT_OFFSET), theme = prop($$props, "theme", 3, "light"), richColors = prop($$props, "richColors", 3, false), duration = prop($$props, "duration", 3, TOAST_LIFETIME), visibleToasts = prop($$props, "visibleToasts", 3, VISIBLE_TOASTS_AMOUNT), toastOptions = prop($$props, "toastOptions", 19, () => ({})), dir = prop($$props, "dir", 7, "auto"), gap = prop($$props, "gap", 3, GAP), pauseWhenPageIsHidden = prop($$props, "pauseWhenPageIsHidden", 3, false), containerAriaLabel = prop($$props, "containerAriaLabel", 3, "Notifications"), closeButtonAriaLabel = prop($$props, "closeButtonAriaLabel", 3, "Close toast"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"invert",
		"position",
		"hotkey",
		"expand",
		"closeButton",
		"offset",
		"mobileOffset",
		"theme",
		"richColors",
		"duration",
		"visibleToasts",
		"toastOptions",
		"dir",
		"gap",
		"pauseWhenPageIsHidden",
		"loadingIcon",
		"successIcon",
		"errorIcon",
		"warningIcon",
		"closeIcon",
		"infoIcon",
		"containerAriaLabel",
		"class",
		"closeButtonAriaLabel",
		"onblur",
		"onfocus",
		"onmouseenter",
		"onmousemove",
		"onmouseleave",
		"ondragend",
		"onpointerdown",
		"onpointerup"
	]);
	function getDocumentDirection() {
		if (dir() !== "auto") return dir();
		if (typeof window === "undefined") return "ltr";
		if (typeof document === "undefined") return "ltr";
		const dirAttribute = document.documentElement.getAttribute("dir");
		if (dirAttribute === "auto" || !dirAttribute) {
			untrack(() => dir(window.getComputedStyle(document.documentElement).direction ?? "ltr"));
			return dir();
		}
		untrack(() => dir(dirAttribute));
		return dirAttribute;
	}
	const possiblePositions = user_derived(() => Array.from(new Set([position(), ...toastState.toasts.filter((toast) => toast.position).map((toast) => toast.position)].filter(Boolean))));
	let expanded = state$1(false);
	let interacting = state$1(false);
	let actualTheme = state$1(proxy(getInitialTheme(theme())));
	let listRef = state$1(void 0);
	let lastFocusedElementRef = state$1(null);
	let isFocusWithin = state$1(false);
	const hotkeyLabel = user_derived(() => hotkey().join("+").replace(/Key/g, "").replace(/Digit/g, ""));
	user_effect(() => {
		if (toastState.toasts.length <= 1) set(expanded, false);
	});
	user_effect(() => {
		const toastsToDismiss = toastState.toasts.filter((toast) => toast.dismiss && !toast.delete);
		if (toastsToDismiss.length > 0) toastState.toasts = toastState.toasts.map((toast) => {
			if (toastsToDismiss.find((dismissToast) => dismissToast.id === toast.id)) return {
				...toast,
				delete: true
			};
			return toast;
		});
	});
	user_effect(() => {
		return () => {
			if (get$2(listRef) && get$2(lastFocusedElementRef)) {
				get$2(lastFocusedElementRef).focus({ preventScroll: true });
				set(lastFocusedElementRef, null);
				set(isFocusWithin, false);
			}
		};
	});
	onMount(() => {
		toastState.reset();
		const handleKeydown = (event) => {
			if (hotkey().every((key) => event[key] || event.code === key)) {
				set(expanded, true);
				get$2(listRef)?.focus();
			}
			if (event.code === "Escape" && (document.activeElement === get$2(listRef) || get$2(listRef)?.contains(document.activeElement))) set(expanded, false);
		};
		return on(document, "keydown", handleKeydown);
	});
	user_effect(() => {
		if (theme() !== "system") set(actualTheme, theme());
		if (typeof window !== "undefined") {
			if (theme() === "system") if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) set(actualTheme, DARK);
			else set(actualTheme, LIGHT);
			const mediaQueryList = window.matchMedia("(prefers-color-scheme: dark)");
			const changeHandler = ({ matches }) => {
				if (theme() !== "system") return;
				set(actualTheme, matches ? DARK : LIGHT, true);
			};
			if ("addEventListener" in mediaQueryList) mediaQueryList.addEventListener("change", changeHandler);
			else mediaQueryList.addListener(changeHandler);
		}
	});
	const handleBlur = (event) => {
		$$props.onblur?.(event);
		if (get$2(isFocusWithin) && !event.currentTarget.contains(event.relatedTarget)) {
			set(isFocusWithin, false);
			if (get$2(lastFocusedElementRef)) {
				get$2(lastFocusedElementRef).focus({ preventScroll: true });
				set(lastFocusedElementRef, null);
			}
		}
	};
	const handleFocus = (event) => {
		$$props.onfocus?.(event);
		if (event.target instanceof HTMLElement && event.target.dataset.dismissible === "false") return;
		if (!get$2(isFocusWithin)) {
			set(isFocusWithin, true);
			set(lastFocusedElementRef, event.relatedTarget, true);
		}
	};
	const handlePointerDown = (event) => {
		$$props.onpointerdown?.(event);
		if (event.target instanceof HTMLElement && event.target.dataset.dismissible === "false") return;
		set(interacting, true);
	};
	const handleMouseEnter = (event) => {
		$$props.onmouseenter?.(event);
		set(expanded, true);
	};
	const handleMouseLeave = (event) => {
		$$props.onmouseleave?.(event);
		if (!get$2(interacting)) set(expanded, false);
	};
	const handleMouseMove = (event) => {
		$$props.onmousemove?.(event);
		set(expanded, true);
	};
	const handleDragEnd = (event) => {
		$$props.ondragend?.(event);
		set(expanded, false);
	};
	const handlePointerUp = (event) => {
		$$props.onpointerup?.(event);
		set(interacting, false);
	};
	sonnerContext.set(new SonnerState());
	var section = root$6();
	set_attribute(section, "tabindex", -1);
	var node = child(section);
	var consequent_10 = ($$anchor) => {
		var fragment = comment();
		each(first_child(fragment), 18, () => get$2(possiblePositions), (position) => position, ($$anchor, position, index, $$array) => {
			const computed_const = user_derived(() => {
				const [y, x] = position.split("-");
				return {
					y,
					x
				};
			});
			const offsetObject = user_derived(() => getOffsetObject(offset(), mobileOffset()));
			var ol = root_2$8();
			attribute_effect(ol, ($0) => ({
				tabindex: -1,
				dir: $0,
				class: $$props.class,
				"data-sonner-toaster": true,
				"data-sonner-theme": get$2(actualTheme),
				"data-y-position": get$2(computed_const).y,
				"data-x-position": get$2(computed_const).x,
				style: $$props.style,
				onblur: handleBlur,
				onfocus: handleFocus,
				onmouseenter: handleMouseEnter,
				onmousemove: handleMouseMove,
				onmouseleave: handleMouseLeave,
				ondragend: handleDragEnd,
				onpointerdown: handlePointerDown,
				onpointerup: handlePointerUp,
				...restProps,
				[STYLE]: {
					"--front-toast-height": `${toastState.heights[0]?.height}px`,
					"--width": `${TOAST_WIDTH}px`,
					"--gap": `${gap()}px`,
					"--offset-top": get$2(offsetObject)["--offset-top"],
					"--offset-right": get$2(offsetObject)["--offset-right"],
					"--offset-bottom": get$2(offsetObject)["--offset-bottom"],
					"--offset-left": get$2(offsetObject)["--offset-left"],
					"--mobile-offset-top": get$2(offsetObject)["--mobile-offset-top"],
					"--mobile-offset-right": get$2(offsetObject)["--mobile-offset-right"],
					"--mobile-offset-bottom": get$2(offsetObject)["--mobile-offset-bottom"],
					"--mobile-offset-left": get$2(offsetObject)["--mobile-offset-left"]
				}
			}), [() => getDocumentDirection()], void 0, void 0, "svelte-nbs0zk");
			each(ol, 23, () => toastState.toasts.filter((toast) => !toast.position && get$2(index) === 0 || toast.position === position), (toast) => toast.id, ($$anchor, toast, index, $$array_1) => {
				{
					const successIcon = ($$anchor) => {
						var fragment_2 = comment();
						var node_2 = first_child(fragment_2);
						var consequent = ($$anchor) => {
							var fragment_3 = comment();
							snippet(first_child(fragment_3), () => $$props.successIcon ?? noop$1);
							append($$anchor, fragment_3);
						};
						var consequent_1 = ($$anchor) => {
							SuccessIcon($$anchor, {});
						};
						if_block(node_2, ($$render) => {
							if ($$props.successIcon) $$render(consequent);
							else if ($$props.successIcon !== null) $$render(consequent_1, 1);
						});
						append($$anchor, fragment_2);
					};
					const errorIcon = ($$anchor) => {
						var fragment_5 = comment();
						var node_4 = first_child(fragment_5);
						var consequent_2 = ($$anchor) => {
							var fragment_6 = comment();
							snippet(first_child(fragment_6), () => $$props.errorIcon ?? noop$1);
							append($$anchor, fragment_6);
						};
						var consequent_3 = ($$anchor) => {
							ErrorIcon($$anchor, {});
						};
						if_block(node_4, ($$render) => {
							if ($$props.errorIcon) $$render(consequent_2);
							else if ($$props.errorIcon !== null) $$render(consequent_3, 1);
						});
						append($$anchor, fragment_5);
					};
					const warningIcon = ($$anchor) => {
						var fragment_8 = comment();
						var node_6 = first_child(fragment_8);
						var consequent_4 = ($$anchor) => {
							var fragment_9 = comment();
							snippet(first_child(fragment_9), () => $$props.warningIcon ?? noop$1);
							append($$anchor, fragment_9);
						};
						var consequent_5 = ($$anchor) => {
							WarningIcon($$anchor, {});
						};
						if_block(node_6, ($$render) => {
							if ($$props.warningIcon) $$render(consequent_4);
							else if ($$props.warningIcon !== null) $$render(consequent_5, 1);
						});
						append($$anchor, fragment_8);
					};
					const infoIcon = ($$anchor) => {
						var fragment_11 = comment();
						var node_8 = first_child(fragment_11);
						var consequent_6 = ($$anchor) => {
							var fragment_12 = comment();
							snippet(first_child(fragment_12), () => $$props.infoIcon ?? noop$1);
							append($$anchor, fragment_12);
						};
						var consequent_7 = ($$anchor) => {
							InfoIcon($$anchor, {});
						};
						if_block(node_8, ($$render) => {
							if ($$props.infoIcon) $$render(consequent_6);
							else if ($$props.infoIcon !== null) $$render(consequent_7, 1);
						});
						append($$anchor, fragment_11);
					};
					const closeIcon = ($$anchor) => {
						var fragment_14 = comment();
						var node_10 = first_child(fragment_14);
						var consequent_8 = ($$anchor) => {
							var fragment_15 = comment();
							snippet(first_child(fragment_15), () => $$props.closeIcon ?? noop$1);
							append($$anchor, fragment_15);
						};
						var consequent_9 = ($$anchor) => {
							CloseIcon($$anchor, {});
						};
						if_block(node_10, ($$render) => {
							if ($$props.closeIcon) $$render(consequent_8);
							else if ($$props.closeIcon !== null) $$render(consequent_9, 1);
						});
						append($$anchor, fragment_14);
					};
					let $0 = user_derived(() => toastOptions()?.duration ?? duration());
					let $1 = user_derived(() => toastOptions()?.class ?? "");
					let $2 = user_derived(() => toastOptions()?.descriptionClass || "");
					let $3 = user_derived(() => toastOptions()?.style ?? "");
					let $4 = user_derived(() => toastOptions().classes || {});
					let $5 = user_derived(() => toastOptions().unstyled ?? false);
					let $6 = user_derived(() => toastOptions()?.cancelButtonStyle ?? "");
					let $7 = user_derived(() => toastOptions()?.actionButtonStyle ?? "");
					let $8 = user_derived(() => toastOptions()?.closeButtonAriaLabel ?? closeButtonAriaLabel());
					Toast($$anchor, {
						get index() {
							return get$2(index);
						},
						get toast() {
							return get$2(toast);
						},
						get defaultRichColors() {
							return richColors();
						},
						get duration() {
							return get$2($0);
						},
						get class() {
							return get$2($1);
						},
						get descriptionClass() {
							return get$2($2);
						},
						get invert() {
							return invert();
						},
						get visibleToasts() {
							return visibleToasts();
						},
						get closeButton() {
							return closeButton();
						},
						get interacting() {
							return get$2(interacting);
						},
						get position() {
							return position;
						},
						get style() {
							return get$2($3);
						},
						get classes() {
							return get$2($4);
						},
						get unstyled() {
							return get$2($5);
						},
						get cancelButtonStyle() {
							return get$2($6);
						},
						get actionButtonStyle() {
							return get$2($7);
						},
						get closeButtonAriaLabel() {
							return get$2($8);
						},
						get expandByDefault() {
							return expand();
						},
						get expanded() {
							return get$2(expanded);
						},
						get pauseWhenPageIsHidden() {
							return pauseWhenPageIsHidden();
						},
						get loadingIcon() {
							return $$props.loadingIcon;
						},
						successIcon,
						errorIcon,
						warningIcon,
						infoIcon,
						closeIcon,
						$$slots: {
							successIcon: true,
							errorIcon: true,
							warningIcon: true,
							infoIcon: true,
							closeIcon: true
						}
					});
				}
			});
			reset(ol);
			bind_this(ol, ($$value) => set(listRef, $$value), () => get$2(listRef));
			template_effect(() => ol.dir = ol.dir);
			append($$anchor, ol);
		});
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if (toastState.toasts.length > 0) $$render(consequent_10);
	});
	reset(section);
	template_effect(() => set_attribute(section, "aria-label", `${containerAriaLabel() ?? ""} ${get$2(hotkeyLabel) ?? ""}`));
	append($$anchor, section);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/Check.svelte
var root_2$7 = from_svg(`<path d="M232.49,80.49l-128,128a12,12,0,0,1-17,0l-56-56a12,12,0,1,1,17-17L96,183,215.51,63.51a12,12,0,0,1,17,17Z"></path>`);
var root_3$6 = from_svg(`<path d="M232,56V200a16,16,0,0,1-16,16H40a16,16,0,0,1-16-16V56A16,16,0,0,1,40,40H216A16,16,0,0,1,232,56Z" opacity="0.2"></path><path d="M205.66,85.66l-96,96a8,8,0,0,1-11.32,0l-40-40a8,8,0,0,1,11.32-11.32L104,164.69l90.34-90.35a8,8,0,0,1,11.32,11.32Z"></path>`, 1);
var root_4$5 = from_svg(`<path d="M216,40H40A16,16,0,0,0,24,56V200a16,16,0,0,0,16,16H216a16,16,0,0,0,16-16V56A16,16,0,0,0,216,40ZM205.66,85.66l-96,96a8,8,0,0,1-11.32,0l-40-40a8,8,0,0,1,11.32-11.32L104,164.69l90.34-90.35a8,8,0,0,1,11.32,11.32Z"></path>`);
var root_5$5 = from_svg(`<path d="M228.24,76.24l-128,128a6,6,0,0,1-8.48,0l-56-56a6,6,0,0,1,8.48-8.48L96,191.51,219.76,67.76a6,6,0,0,1,8.48,8.48Z"></path>`);
var root_6$5 = from_svg(`<path d="M229.66,77.66l-128,128a8,8,0,0,1-11.32,0l-56-56a8,8,0,0,1,11.32-11.32L96,188.69,218.34,66.34a8,8,0,0,1,11.32,11.32Z"></path>`);
var root_7$5 = from_svg(`<path d="M226.83,74.83l-128,128a4,4,0,0,1-5.66,0l-56-56a4,4,0,0,1,5.66-5.66L96,194.34,221.17,69.17a4,4,0,1,1,5.66,5.66Z"></path>`);
var root$5 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function Check($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root$5();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2$7());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3$6();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4$5());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$5());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6$5());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7$5());
	};
	var alternate = ($$anchor) => {
		var text$6 = text();
		text$6.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$6);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/CheckCircle.svelte
var root_2$6 = from_svg(`<path d="M176.49,95.51a12,12,0,0,1,0,17l-56,56a12,12,0,0,1-17,0l-24-24a12,12,0,1,1,17-17L112,143l47.51-47.52A12,12,0,0,1,176.49,95.51ZM236,128A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128Z"></path>`);
var root_3$5 = from_svg(`<path d="M224,128a96,96,0,1,1-96-96A96,96,0,0,1,224,128Z" opacity="0.2"></path><path d="M173.66,98.34a8,8,0,0,1,0,11.32l-56,56a8,8,0,0,1-11.32,0l-24-24a8,8,0,0,1,11.32-11.32L112,148.69l50.34-50.35A8,8,0,0,1,173.66,98.34ZM232,128A104,104,0,1,1,128,24,104.11,104.11,0,0,1,232,128Zm-16,0a88,88,0,1,0-88,88A88.1,88.1,0,0,0,216,128Z"></path>`, 1);
var root_4$4 = from_svg(`<path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm45.66,85.66-56,56a8,8,0,0,1-11.32,0l-24-24a8,8,0,0,1,11.32-11.32L112,148.69l50.34-50.35a8,8,0,0,1,11.32,11.32Z"></path>`);
var root_5$4 = from_svg(`<path d="M172.24,99.76a6,6,0,0,1,0,8.48l-56,56a6,6,0,0,1-8.48,0l-24-24a6,6,0,0,1,8.48-8.48L112,151.51l51.76-51.75A6,6,0,0,1,172.24,99.76ZM230,128A102,102,0,1,1,128,26,102.12,102.12,0,0,1,230,128Zm-12,0a90,90,0,1,0-90,90A90.1,90.1,0,0,0,218,128Z"></path>`);
var root_6$4 = from_svg(`<path d="M173.66,98.34a8,8,0,0,1,0,11.32l-56,56a8,8,0,0,1-11.32,0l-24-24a8,8,0,0,1,11.32-11.32L112,148.69l50.34-50.35A8,8,0,0,1,173.66,98.34ZM232,128A104,104,0,1,1,128,24,104.11,104.11,0,0,1,232,128Zm-16,0a88,88,0,1,0-88,88A88.1,88.1,0,0,0,216,128Z"></path>`);
var root_7$4 = from_svg(`<path d="M170.83,101.17a4,4,0,0,1,0,5.66l-56,56a4,4,0,0,1-5.66,0l-24-24a4,4,0,0,1,5.66-5.66L112,154.34l53.17-53.17A4,4,0,0,1,170.83,101.17ZM228,128A100,100,0,1,1,128,28,100.11,100.11,0,0,1,228,128Zm-8,0a92,92,0,1,0-92,92A92.1,92.1,0,0,0,220,128Z"></path>`);
var root$4 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function CheckCircle($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root$4();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2$6());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3$5();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4$4());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$4());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6$4());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7$4());
	};
	var alternate = ($$anchor) => {
		var text$5 = text();
		text$5.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$5);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/Info.svelte
var root_2$5 = from_svg(`<path d="M108,84a16,16,0,1,1,16,16A16,16,0,0,1,108,84Zm128,44A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128Zm-72,36.68V132a20,20,0,0,0-20-20,12,12,0,0,0-4,23.32V168a20,20,0,0,0,20,20,12,12,0,0,0,4-23.32Z"></path>`);
var root_3$4 = from_svg(`<path d="M224,128a96,96,0,1,1-96-96A96,96,0,0,1,224,128Z" opacity="0.2"></path><path d="M144,176a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176Zm88-48A104,104,0,1,1,128,24,104.11,104.11,0,0,1,232,128Zm-16,0a88,88,0,1,0-88,88A88.1,88.1,0,0,0,216,128ZM124,96a12,12,0,1,0-12-12A12,12,0,0,0,124,96Z"></path>`, 1);
var root_4$3 = from_svg(`<path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm-4,48a12,12,0,1,1-12,12A12,12,0,0,1,124,72Zm12,112a16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40a8,8,0,0,1,0,16Z"></path>`);
var root_5$3 = from_svg(`<path d="M142,176a6,6,0,0,1-6,6,14,14,0,0,1-14-14V128a2,2,0,0,0-2-2,6,6,0,0,1,0-12,14,14,0,0,1,14,14v40a2,2,0,0,0,2,2A6,6,0,0,1,142,176ZM124,94a10,10,0,1,0-10-10A10,10,0,0,0,124,94Zm106,34A102,102,0,1,1,128,26,102.12,102.12,0,0,1,230,128Zm-12,0a90,90,0,1,0-90,90A90.1,90.1,0,0,0,218,128Z"></path>`);
var root_6$3 = from_svg(`<path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"></path>`);
var root_7$3 = from_svg(`<path d="M140,176a4,4,0,0,1-4,4,12,12,0,0,1-12-12V128a4,4,0,0,0-4-4,4,4,0,0,1,0-8,12,12,0,0,1,12,12v40a4,4,0,0,0,4,4A4,4,0,0,1,140,176ZM124,92a8,8,0,1,0-8-8A8,8,0,0,0,124,92Zm104,36A100,100,0,1,1,128,28,100.11,100.11,0,0,1,228,128Zm-8,0a92,92,0,1,0-92,92A92.1,92.1,0,0,0,220,128Z"></path>`);
var root$3 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function Info($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root$3();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2$5());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3$4();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4$3());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$3());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6$3());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7$3());
	};
	var alternate = ($$anchor) => {
		var text$4 = text();
		text$4.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$4);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/Warning.svelte
var root_2$4 = from_svg(`<path d="M240.26,186.1,152.81,34.23h0a28.74,28.74,0,0,0-49.62,0L15.74,186.1a27.45,27.45,0,0,0,0,27.71A28.31,28.31,0,0,0,40.55,228h174.9a28.31,28.31,0,0,0,24.79-14.19A27.45,27.45,0,0,0,240.26,186.1Zm-20.8,15.7a4.46,4.46,0,0,1-4,2.2H40.55a4.46,4.46,0,0,1-4-2.2,3.56,3.56,0,0,1,0-3.73L124,46.2a4.77,4.77,0,0,1,8,0l87.44,151.87A3.56,3.56,0,0,1,219.46,201.8ZM116,136V104a12,12,0,0,1,24,0v32a12,12,0,0,1-24,0Zm28,40a16,16,0,1,1-16-16A16,16,0,0,1,144,176Z"></path>`);
var root_3$3 = from_svg(`<path d="M215.46,216H40.54C27.92,216,20,202.79,26.13,192.09L113.59,40.22c6.3-11,22.52-11,28.82,0l87.46,151.87C236,202.79,228.08,216,215.46,216Z" opacity="0.2"></path><path d="M236.8,188.09,149.35,36.22h0a24.76,24.76,0,0,0-42.7,0L19.2,188.09a23.51,23.51,0,0,0,0,23.72A24.35,24.35,0,0,0,40.55,224h174.9a24.35,24.35,0,0,0,21.33-12.19A23.51,23.51,0,0,0,236.8,188.09ZM222.93,203.8a8.5,8.5,0,0,1-7.48,4.2H40.55a8.5,8.5,0,0,1-7.48-4.2,7.59,7.59,0,0,1,0-7.72L120.52,44.21a8.75,8.75,0,0,1,15,0l87.45,151.87A7.59,7.59,0,0,1,222.93,203.8ZM120,144V104a8,8,0,0,1,16,0v40a8,8,0,0,1-16,0Zm20,36a12,12,0,1,1-12-12A12,12,0,0,1,140,180Z"></path>`, 1);
var root_4$2 = from_svg(`<path d="M236.8,188.09,149.35,36.22h0a24.76,24.76,0,0,0-42.7,0L19.2,188.09a23.51,23.51,0,0,0,0,23.72A24.35,24.35,0,0,0,40.55,224h174.9a24.35,24.35,0,0,0,21.33-12.19A23.51,23.51,0,0,0,236.8,188.09ZM120,104a8,8,0,0,1,16,0v40a8,8,0,0,1-16,0Zm8,88a12,12,0,1,1,12-12A12,12,0,0,1,128,192Z"></path>`);
var root_5$2 = from_svg(`<path d="M235.07,189.09,147.61,37.22h0a22.75,22.75,0,0,0-39.22,0L20.93,189.09a21.53,21.53,0,0,0,0,21.72A22.35,22.35,0,0,0,40.55,222h174.9a22.35,22.35,0,0,0,19.6-11.19A21.53,21.53,0,0,0,235.07,189.09ZM224.66,204.8a10.46,10.46,0,0,1-9.21,5.2H40.55a10.46,10.46,0,0,1-9.21-5.2,9.51,9.51,0,0,1,0-9.72L118.79,43.21a10.75,10.75,0,0,1,18.42,0l87.46,151.87A9.51,9.51,0,0,1,224.66,204.8ZM122,144V104a6,6,0,0,1,12,0v40a6,6,0,0,1-12,0Zm16,36a10,10,0,1,1-10-10A10,10,0,0,1,138,180Z"></path>`);
var root_6$2 = from_svg(`<path d="M236.8,188.09,149.35,36.22h0a24.76,24.76,0,0,0-42.7,0L19.2,188.09a23.51,23.51,0,0,0,0,23.72A24.35,24.35,0,0,0,40.55,224h174.9a24.35,24.35,0,0,0,21.33-12.19A23.51,23.51,0,0,0,236.8,188.09ZM222.93,203.8a8.5,8.5,0,0,1-7.48,4.2H40.55a8.5,8.5,0,0,1-7.48-4.2,7.59,7.59,0,0,1,0-7.72L120.52,44.21a8.75,8.75,0,0,1,15,0l87.45,151.87A7.59,7.59,0,0,1,222.93,203.8ZM120,144V104a8,8,0,0,1,16,0v40a8,8,0,0,1-16,0Zm20,36a12,12,0,1,1-12-12A12,12,0,0,1,140,180Z"></path>`);
var root_7$2 = from_svg(`<path d="M233.34,190.09,145.88,38.22h0a20.75,20.75,0,0,0-35.76,0L22.66,190.09a19.52,19.52,0,0,0,0,19.71A20.36,20.36,0,0,0,40.54,220H215.46a20.36,20.36,0,0,0,17.86-10.2A19.52,19.52,0,0,0,233.34,190.09ZM226.4,205.8a12.47,12.47,0,0,1-10.94,6.2H40.54a12.47,12.47,0,0,1-10.94-6.2,11.45,11.45,0,0,1,0-11.72L117.05,42.21a12.76,12.76,0,0,1,21.9,0L226.4,194.08A11.45,11.45,0,0,1,226.4,205.8ZM124,144V104a4,4,0,0,1,8,0v40a4,4,0,0,1-8,0Zm12,36a8,8,0,1,1-8-8A8,8,0,0,1,136,180Z"></path>`);
var root$2 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function Warning($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root$2();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2$4());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3$3();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4$2());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$2());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6$2());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7$2());
	};
	var alternate = ($$anchor) => {
		var text$3 = text();
		text$3.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$3);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/XCircle.svelte
var root_2$3 = from_svg(`<path d="M168.49,104.49,145,128l23.52,23.51a12,12,0,0,1-17,17L128,145l-23.51,23.52a12,12,0,0,1-17-17L111,128,87.51,104.49a12,12,0,0,1,17-17L128,111l23.51-23.52a12,12,0,0,1,17,17ZM236,128A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128Z"></path>`);
var root_3$2 = from_svg(`<path d="M224,128a96,96,0,1,1-96-96A96,96,0,0,1,224,128Z" opacity="0.2"></path><path d="M165.66,101.66,139.31,128l26.35,26.34a8,8,0,0,1-11.32,11.32L128,139.31l-26.34,26.35a8,8,0,0,1-11.32-11.32L116.69,128,90.34,101.66a8,8,0,0,1,11.32-11.32L128,116.69l26.34-26.35a8,8,0,0,1,11.32,11.32ZM232,128A104,104,0,1,1,128,24,104.11,104.11,0,0,1,232,128Zm-16,0a88,88,0,1,0-88,88A88.1,88.1,0,0,0,216,128Z"></path>`, 1);
var root_4$1 = from_svg(`<path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm37.66,130.34a8,8,0,0,1-11.32,11.32L128,139.31l-26.34,26.35a8,8,0,0,1-11.32-11.32L116.69,128,90.34,101.66a8,8,0,0,1,11.32-11.32L128,116.69l26.34-26.35a8,8,0,0,1,11.32,11.32L139.31,128Z"></path>`);
var root_5$1 = from_svg(`<path d="M164.24,100.24,136.48,128l27.76,27.76a6,6,0,1,1-8.48,8.48L128,136.48l-27.76,27.76a6,6,0,0,1-8.48-8.48L119.52,128,91.76,100.24a6,6,0,0,1,8.48-8.48L128,119.52l27.76-27.76a6,6,0,0,1,8.48,8.48ZM230,128A102,102,0,1,1,128,26,102.12,102.12,0,0,1,230,128Zm-12,0a90,90,0,1,0-90,90A90.1,90.1,0,0,0,218,128Z"></path>`);
var root_6$1 = from_svg(`<path d="M165.66,101.66,139.31,128l26.35,26.34a8,8,0,0,1-11.32,11.32L128,139.31l-26.34,26.35a8,8,0,0,1-11.32-11.32L116.69,128,90.34,101.66a8,8,0,0,1,11.32-11.32L128,116.69l26.34-26.35a8,8,0,0,1,11.32,11.32ZM232,128A104,104,0,1,1,128,24,104.11,104.11,0,0,1,232,128Zm-16,0a88,88,0,1,0-88,88A88.1,88.1,0,0,0,216,128Z"></path>`);
var root_7$1 = from_svg(`<path d="M162.83,98.83,133.66,128l29.17,29.17a4,4,0,0,1-5.66,5.66L128,133.66,98.83,162.83a4,4,0,0,1-5.66-5.66L122.34,128,93.17,98.83a4,4,0,0,1,5.66-5.66L128,122.34l29.17-29.17a4,4,0,1,1,5.66,5.66ZM228,128A100,100,0,1,1,128,28,100.11,100.11,0,0,1,228,128Zm-8,0a92,92,0,1,0-92,92A92.1,92.1,0,0,0,220,128Z"></path>`);
var root$1 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function XCircle($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root$1();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2$3());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3$2();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4$1());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$1());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6$1());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7$1());
	};
	var alternate = ($$anchor) => {
		var text$2 = text();
		text$2.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$2);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/sonner/sonner.svelte
function Sonner_1($$anchor, $$props) {
	push($$props, true);
	let restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy"
	]);
	{
		const loadingIcon = ($$anchor) => {
			Spinner($$anchor, { class: "size-4 animate-spin" });
		};
		const successIcon = ($$anchor) => {
			CheckCircle($$anchor, { class: "size-4" });
		};
		const errorIcon = ($$anchor) => {
			XCircle($$anchor, { class: "size-4" });
		};
		const infoIcon = ($$anchor) => {
			Info($$anchor, { class: "size-4" });
		};
		const warningIcon = ($$anchor) => {
			Warning($$anchor, { class: "size-4" });
		};
		Toaster($$anchor, spread_props({
			get theme() {
				return derivedMode.current;
			},
			class: "toaster group",
			style: "--normal-bg: var(--color-popover); --normal-text: var(--color-popover-foreground); --normal-border: var(--color-border);"
		}, () => restProps, {
			loadingIcon,
			successIcon,
			errorIcon,
			infoIcon,
			warningIcon,
			$$slots: {
				loadingIcon: true,
				successIcon: true,
				errorIcon: true,
				infoIcon: true,
				warningIcon: true
			}
		}));
	}
	pop();
}
//#endregion
//#region extension/svelte/components/ui/tooltip/tooltip.svelte
function Tooltip($$anchor, $$props) {
	push($$props, true);
	let open = prop($$props, "open", 15, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"open"
	]);
	var fragment = comment();
	component(first_child(fragment), () => Tooltip$1, ($$anchor, TooltipPrimitive_Root) => {
		TooltipPrimitive_Root($$anchor, spread_props(() => restProps, {
			get open() {
				return open();
			},
			set open($$value) {
				open($$value);
			}
		}));
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/tooltip/tooltip-portal.svelte
function Tooltip_portal($$anchor, $$props) {
	let restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy"
	]);
	var fragment = comment();
	component(first_child(fragment), () => Portal, ($$anchor, TooltipPrimitive_Portal) => {
		TooltipPrimitive_Portal($$anchor, spread_props(() => restProps));
	});
	append($$anchor, fragment);
}
//#endregion
//#region extension/svelte/components/ui/tooltip/tooltip-content.svelte
var root_3$1 = from_html(`<div></div>`);
var root_2$2 = from_html(`<!> <!>`, 1);
function Tooltip_content($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), sideOffset = prop($$props, "sideOffset", 3, 0), side = prop($$props, "side", 3, "top"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"sideOffset",
		"side",
		"children",
		"arrowClasses",
		"portalProps"
	]);
	Tooltip_portal($$anchor, spread_props(() => $$props.portalProps, {
		children: ($$anchor, $$slotProps) => {
			var fragment_1 = comment();
			var node = first_child(fragment_1);
			{
				let $0 = user_derived(() => cn$1("data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-[state=delayed-open]:animate-in data-[state=delayed-open]:fade-in-0 data-[state=delayed-open]:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs has-data-[slot=kbd]:pr-1.5 **:data-[slot=kbd]:relative **:data-[slot=kbd]:isolate **:data-[slot=kbd]:z-50 **:data-[slot=kbd]:rounded-sm bg-foreground text-background z-50 w-fit max-w-xs origin-(--bits-tooltip-content-transform-origin)", $$props.class));
				component(node, () => Tooltip_content$1, ($$anchor, TooltipPrimitive_Content) => {
					TooltipPrimitive_Content($$anchor, spread_props({
						"data-slot": "tooltip-content",
						get sideOffset() {
							return sideOffset();
						},
						get side() {
							return side();
						},
						get class() {
							return get$2($0);
						}
					}, () => restProps, {
						get ref() {
							return ref();
						},
						set ref($$value) {
							ref($$value);
						},
						children: ($$anchor, $$slotProps) => {
							var fragment_2 = root_2$2();
							var node_1 = first_child(fragment_2);
							snippet(node_1, () => $$props.children ?? noop$1);
							var node_2 = sibling(node_1, 2);
							{
								const child = ($$anchor, $$arg0) => {
									let props = () => $$arg0?.().props;
									var div = root_3$1();
									attribute_effect(div, ($0) => ({
										class: $0,
										...props()
									}), [() => cn$1("size-2.5 translate-y-[calc(-50%-2px)] rotate-45 rounded-[2px] bg-foreground fill-foreground z-50", "data-[side=top]:translate-x-1/2 data-[side=top]:translate-y-[calc(-50%+2px)]", "data-[side=bottom]:-translate-x-1/2 data-[side=bottom]:-translate-y-[calc(-50%+1px)]", "data-[side=right]:translate-x-[calc(50%+2px)] data-[side=right]:translate-y-1/2", "data-[side=left]:-translate-y-[calc(50%-3px)]", $$props.arrowClasses)]);
									append($$anchor, div);
								};
								component(node_2, () => Tooltip_arrow, ($$anchor, TooltipPrimitive_Arrow) => {
									TooltipPrimitive_Arrow($$anchor, {
										child,
										$$slots: { child: true }
									});
								});
							}
							append($$anchor, fragment_2);
						},
						$$slots: { default: true }
					}));
				});
			}
			append($$anchor, fragment_1);
		},
		$$slots: { default: true }
	}));
	pop();
}
//#endregion
//#region extension/svelte/components/ui/tooltip/tooltip-provider.svelte
function Tooltip_provider($$anchor, $$props) {
	let delayDuration = prop($$props, "delayDuration", 3, 0), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"delayDuration"
	]);
	var fragment = comment();
	component(first_child(fragment), () => Tooltip_provider$1, ($$anchor, TooltipPrimitive_Provider) => {
		TooltipPrimitive_Provider($$anchor, spread_props({ get delayDuration() {
			return delayDuration();
		} }, () => restProps));
	});
	append($$anchor, fragment);
}
//#endregion
//#region extension/svelte/components/ui/tooltip/tooltip-trigger.svelte
function Tooltip_trigger($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref"
	]);
	var fragment = comment();
	component(first_child(fragment), () => Tooltip_trigger$1, ($$anchor, TooltipPrimitive_Trigger) => {
		TooltipPrimitive_Trigger($$anchor, spread_props({ "data-slot": "tooltip-trigger" }, () => restProps, {
			get ref() {
				return ref();
			},
			set ref($$value) {
				ref($$value);
			}
		}));
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/svelte-spa-router/dist/active.svelte.js
var nodes = [];
var location = "";
function checkActive(el) {
	const matchesLocation = el.pattern.test(location);
	toggleClasses(el, el.className, matchesLocation);
	toggleClasses(el, el.inactiveClassName, !matchesLocation);
}
function toggleClasses(el, className, shouldAdd) {
	(className || "").split(" ").forEach((cls) => {
		if (!cls) return;
		el.node.classList.remove(cls);
		if (shouldAdd) el.node.classList.add(cls);
	});
}
effect_root(() => {
	user_effect(() => {
		const value = router.loc;
		location = value.location + (value.querystring ? "?" + value.querystring : "");
		nodes.forEach(checkActive);
	});
});
/**
* Svelte Action for automatically adding the "active" class to elements (links, or any other DOM element) when the current location matches a certain path.
*
* @param node - The target node (automatically set by Svelte)
* @param opts - Can be an object of type `ActiveOptions`, or a string (or regular expression) representing `ActiveOptions.path`.
* @returns Destroy function
*/
function active(node, opts) {
	let options;
	if (typeof opts == "string" || opts instanceof RegExp) options = { path: opts };
	else options = opts ?? {};
	if (!options.path && node.hasAttribute("href")) {
		const href = node.getAttribute("href");
		if (href) options.path = href.length > 1 && href.charAt(0) == "#" ? href.substring(1) : href;
	}
	if (!options.className) options.className = "active";
	if (!options.path || typeof options.path == "string" && (options.path.length < 1 || options.path.charAt(0) != "/" && options.path.charAt(0) != "*")) throw Error("Invalid value for \"path\" argument");
	const pattern = typeof options.path == "string" ? parse(options.path).pattern : options.path;
	const el = {
		node,
		className: options.className,
		inactiveClassName: options.inactiveClassName,
		pattern
	};
	nodes.push(el);
	checkActive(el);
	return { destroy() {
		nodes.splice(nodes.indexOf(el), 1);
	} };
}
//#endregion
//#region extension/svelte/components/ui/input/input.svelte
var root_1 = from_html(`<input/>`);
var root_2$1 = from_html(`<input/>`);
function Input($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), value = prop($$props, "value", 15), files = prop($$props, "files", 15), dataSlot = prop($$props, "data-slot", 3, "input"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"value",
		"type",
		"files",
		"class",
		"data-slot"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var input = root_1();
		attribute_effect(input, ($0) => ({
			"data-slot": dataSlot(),
			class: $0,
			type: "file",
			...restProps
		}), [() => cn$1("dark:bg-input/30 border-input focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 disabled:bg-input/50 dark:disabled:bg-input/80 h-8 rounded-lg border bg-transparent px-2.5 py-1 text-base transition-colors file:h-6 file:text-sm file:font-medium focus-visible:ring-3 aria-invalid:ring-3 md:text-sm file:text-foreground placeholder:text-muted-foreground w-full min-w-0 outline-none file:inline-flex file:border-0 file:bg-transparent disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50", $$props.class)], void 0, void 0, void 0, true);
		bind_this(input, ($$value) => ref($$value), () => ref());
		bind_files(input, files);
		bind_value(input, value);
		append($$anchor, input);
	};
	var alternate = ($$anchor) => {
		var input_1 = root_2$1();
		attribute_effect(input_1, ($0) => ({
			"data-slot": dataSlot(),
			class: $0,
			type: $$props.type,
			...restProps
		}), [() => cn$1("dark:bg-input/30 border-input focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 disabled:bg-input/50 dark:disabled:bg-input/80 h-8 rounded-lg border bg-transparent px-2.5 py-1 text-base transition-colors file:h-6 file:text-sm file:font-medium focus-visible:ring-3 aria-invalid:ring-3 md:text-sm file:text-foreground placeholder:text-muted-foreground w-full min-w-0 outline-none file:inline-flex file:border-0 file:bg-transparent disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50", $$props.class)], void 0, void 0, void 0, true);
		bind_this(input_1, ($$value) => ref($$value), () => ref());
		bind_value(input_1, value);
		append($$anchor, input_1);
	};
	if_block(node, ($$render) => {
		if ($$props.type === "file") $$render(consequent);
		else $$render(alternate, -1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/phosphor-svelte/lib/TrashIcon.svelte
var root_2 = from_svg(`<path d="M216,48H180V36A28,28,0,0,0,152,8H104A28,28,0,0,0,76,36V48H40a12,12,0,0,0,0,24h4V208a20,20,0,0,0,20,20H192a20,20,0,0,0,20-20V72h4a12,12,0,0,0,0-24ZM100,36a4,4,0,0,1,4-4h48a4,4,0,0,1,4,4V48H100Zm88,168H68V72H188ZM116,104v64a12,12,0,0,1-24,0V104a12,12,0,0,1,24,0Zm48,0v64a12,12,0,0,1-24,0V104a12,12,0,0,1,24,0Z"></path>`);
var root_3 = from_svg(`<path d="M200,56V208a8,8,0,0,1-8,8H64a8,8,0,0,1-8-8V56Z" opacity="0.2"></path><path d="M216,48H176V40a24,24,0,0,0-24-24H104A24,24,0,0,0,80,40v8H40a8,8,0,0,0,0,16h8V208a16,16,0,0,0,16,16H192a16,16,0,0,0,16-16V64h8a8,8,0,0,0,0-16ZM96,40a8,8,0,0,1,8-8h48a8,8,0,0,1,8,8v8H96Zm96,168H64V64H192ZM112,104v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm48,0v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Z"></path>`, 1);
var root_4 = from_svg(`<path d="M216,48H176V40a24,24,0,0,0-24-24H104A24,24,0,0,0,80,40v8H40a8,8,0,0,0,0,16h8V208a16,16,0,0,0,16,16H192a16,16,0,0,0,16-16V64h8a8,8,0,0,0,0-16ZM112,168a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm48,0a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm0-120H96V40a8,8,0,0,1,8-8h48a8,8,0,0,1,8,8Z"></path>`);
var root_5 = from_svg(`<path d="M216,50H174V40a22,22,0,0,0-22-22H104A22,22,0,0,0,82,40V50H40a6,6,0,0,0,0,12H50V208a14,14,0,0,0,14,14H192a14,14,0,0,0,14-14V62h10a6,6,0,0,0,0-12ZM94,40a10,10,0,0,1,10-10h48a10,10,0,0,1,10,10V50H94ZM194,208a2,2,0,0,1-2,2H64a2,2,0,0,1-2-2V62H194ZM110,104v64a6,6,0,0,1-12,0V104a6,6,0,0,1,12,0Zm48,0v64a6,6,0,0,1-12,0V104a6,6,0,0,1,12,0Z"></path>`);
var root_6 = from_svg(`<path d="M216,48H176V40a24,24,0,0,0-24-24H104A24,24,0,0,0,80,40v8H40a8,8,0,0,0,0,16h8V208a16,16,0,0,0,16,16H192a16,16,0,0,0,16-16V64h8a8,8,0,0,0,0-16ZM96,40a8,8,0,0,1,8-8h48a8,8,0,0,1,8,8v8H96Zm96,168H64V64H192ZM112,104v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm48,0v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Z"></path>`);
var root_7 = from_svg(`<path d="M216,52H172V40a20,20,0,0,0-20-20H104A20,20,0,0,0,84,40V52H40a4,4,0,0,0,0,8H52V208a12,12,0,0,0,12,12H192a12,12,0,0,0,12-12V60h12a4,4,0,0,0,0-8ZM92,40a12,12,0,0,1,12-12h48a12,12,0,0,1,12,12V52H92ZM196,208a4,4,0,0,1-4,4H64a4,4,0,0,1-4-4V60H196ZM108,104v64a4,4,0,0,1-8,0V104a4,4,0,0,1,8,0Zm48,0v64a4,4,0,0,1-8,0V104a4,4,0,0,1,8,0Z"></path>`);
var root = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function TrashIcon($$anchor, $$props) {
	push($$props, true);
	const ctx = getIconContext();
	let props = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children"
	]);
	let weight = user_derived(() => $$props.weight ?? ctx.weight ?? "regular");
	let color = user_derived(() => $$props.color ?? ctx.color ?? "currentColor");
	let size = user_derived(() => $$props.size ?? ctx.size ?? "1em");
	let mirrored = user_derived(() => $$props.mirrored ?? ctx.mirrored ?? false);
	function svgAttr(obj) {
		let { weight, color, size, mirrored, ...attrs } = obj;
		return attrs;
	}
	var svg = root();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get$2(size),
		height: get$2(size),
		fill: get$2(color),
		transform: get$2(mirrored) ? "scale(-1, 1)" : void 0,
		viewBox: "0 0 256 256",
		...$0,
		...$1
	}), [() => svgAttr(ctx), () => svgAttr(props)]);
	var node = child(svg);
	var consequent = ($$anchor) => {
		var fragment = comment();
		snippet(first_child(fragment), () => $$props.children);
		append($$anchor, fragment);
	};
	if_block(node, ($$render) => {
		if ($$props.children) $$render(consequent);
	});
	var node_2 = sibling(node, 2);
	var consequent_1 = ($$anchor) => {
		append($$anchor, root_2());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3();
		next$1();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7());
	};
	var alternate = ($$anchor) => {
		var text$1 = text();
		text$1.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$1);
	};
	if_block(node_2, ($$render) => {
		if (get$2(weight) === "bold") $$render(consequent_1);
		else if (get$2(weight) === "duotone") $$render(consequent_2, 1);
		else if (get$2(weight) === "fill") $$render(consequent_3, 2);
		else if (get$2(weight) === "light") $$render(consequent_4, 3);
		else if (get$2(weight) === "regular") $$render(consequent_5, 4);
		else if (get$2(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
export { DialogRootState as $, getFloatingContentCSSVars as A, DOMContext as At, boxAutoReset as B, executeCallbacks as Bt, formatTime as C, boolToTrueOrUndef as Ct, Popper_layer as D, getDataOpenClosed as Dt, Popper_layer_force_mount as E, getDataChecked as Et, Text_selection_layer as F, Previous as Ft, next as G, router as Gt, forward as H, Router as Ht, Focus_scope as I, watch$1 as It, Portal as J, prev as K, Escape_layer as L, Context$1 as Lt, Dialog_overlay as M, afterSleep as Mt, Scroll_lock as N, onMountEffect as Nt, Floating_layer as O, getDataTransitionAttrs as Ot, useId as P, onDestroyEffect as Pt, DialogContentState as Q, Dismissible_layer as R, srOnlyStyles as Rt, formatNumber as S, boolToStrTrueOrUndef as St, Separator as T, getAriaChecked as Tt, getNextMatch as U, link as Ut, backward as V, boxWith as Vt, isValidIndex as W, replace as Wt, AlertDialogCancelState as X, Dialog_title as Y, DialogCloseState as Z, capitalizeText as _, PAGE_DOWN as _t, Tooltip_provider as a, isHTMLElement$1 as at, formatBytes as b, boolToEmptyStrOrUndef as bt, Sonner_1 as c, ARROW_LEFT as ct, Spinner as d, CAPS_LOCK as dt, createId as et, getIconContext as f, CONTROL as ft, applyPlural as g, META as gt, tv as h, HOME as ht, Tooltip_trigger as i, isElementOrSVGElement as it, Dialog_description as j, afterTick as jt, FloatingAnchorState as k, attachRef as kt, Check as l, ARROW_RIGHT as lt, buttonVariants as m, ESCAPE as mt, Input as n, PresenceManager as nt, Tooltip_content as o, isIOS as ot, Button as p, ENTER as pt, getFirstNonCommentChild as q, active as r, RovingFocusGroup as rt, Tooltip as s, ARROW_DOWN as st, TrashIcon as t, noop as tt, toast as u, ARROW_UP as ut, daySuffix as v, PAGE_UP as vt, toSeconds as w, createBitsAttrs as wt, formatDate as x, boolToStr as xt, dropDecimals as y, SHIFT as yt, DOMTypeahead as z, mergeProps as zt };

//# sourceMappingURL=TrashIcon-CnKkSyHV.js.map