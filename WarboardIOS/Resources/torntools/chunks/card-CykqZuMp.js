import { t as browser } from "./browser-DV2XfOQj.js";
import { A as prop, At as user_derived, C as ttStorage, Ct as first_child, G as element, Ht as next, I as bind_value, K as component, M as spread_props, P as bind_this, Q as if_block, R as attribute_effect, Rt as pop, St as child, T as cn, Ut as reset, Wt as noop, at as from_svg, f as SCRIPT_TYPE, h as isIntNumber, i as api, it as from_html, j as rest_props, l as torndata, m as getCookie, mt as get, nt as append, ot as props_id, p as TO_MILLIS, q as snippet, rt as comment, s as settings, st as text, u as userdata, wt as sibling, xt as remove_textarea_child, zt as push } from "./dist-DghMY0ja.js";
import { $ as DialogRootState, F as Text_selection_layer, I as Focus_scope, J as Portal, L as Escape_layer, M as Dialog_overlay$1, N as Scroll_lock, Q as DialogContentState, R as Dismissible_layer, S as formatNumber, Vt as boxWith, Y as Dialog_title$1, Z as DialogCloseState, d as Spinner$1, et as createId, f as getIconContext, h as tv, j as Dialog_description$1, p as Button, tt as noop$1, zt as mergeProps } from "./TrashIcon-CnKkSyHV.js";
//#region \0rolldown/runtime.js
var __create = Object.create;
var __defProp$1 = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp$1 = Object.prototype.hasOwnProperty;
var __commonJSMin = (cb, mod) => () => (mod || cb((mod = { exports: {} }).exports, mod), mod.exports);
var __copyProps = (to, from, except, desc) => {
	if (from && typeof from === "object" || typeof from === "function") for (var keys = __getOwnPropNames(from), i = 0, n = keys.length, key; i < n; i++) {
		key = keys[i];
		if (!__hasOwnProp$1.call(to, key) && key !== except) __defProp$1(to, key, {
			get: ((k) => from[k]).bind(null, key),
			enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable
		});
	}
	return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(isNodeMode || !mod || !mod.__esModule ? __defProp$1(target, "default", {
	value: mod,
	enumerable: true
}) : target, mod));
//#endregion
//#region node_modules/bits-ui/dist/bits/dialog/components/dialog.svelte
function Dialog$1($$anchor, $$props) {
	push($$props, true);
	let open = prop($$props, "open", 15, false), onOpenChange = prop($$props, "onOpenChange", 3, noop$1), onOpenChangeComplete = prop($$props, "onOpenChangeComplete", 3, noop$1);
	DialogRootState.create({
		variant: boxWith(() => "dialog"),
		open: boxWith(() => open(), (v) => {
			open(v);
			onOpenChange()(v);
		}),
		onOpenChangeComplete: boxWith(() => onOpenChangeComplete())
	});
	var fragment = comment();
	snippet(first_child(fragment), () => $$props.children ?? noop);
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region node_modules/bits-ui/dist/bits/dialog/components/dialog-close.svelte
var root_2$2 = from_html(`<button><!></button>`);
function Dialog_close($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), ref = prop($$props, "ref", 15, null), disabled = prop($$props, "disabled", 3, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"children",
		"child",
		"id",
		"ref",
		"disabled"
	]);
	const closeState = DialogCloseState.create({
		variant: boxWith(() => "close"),
		id: boxWith(() => id()),
		ref: boxWith(() => ref(), (v) => ref(v)),
		disabled: boxWith(() => Boolean(disabled()))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, closeState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent = ($$anchor) => {
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.child, () => ({ props: get(mergedProps) }));
		append($$anchor, fragment_1);
	};
	var alternate = ($$anchor) => {
		var button = root_2$2();
		attribute_effect(button, () => ({ ...get(mergedProps) }));
		snippet(child(button), () => $$props.children ?? noop);
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
//#region node_modules/bits-ui/dist/bits/dialog/components/dialog-content.svelte
var root_6$1 = from_html(`<!> <!>`, 1);
var root_8 = from_html(`<!> <div><!></div>`, 1);
function Dialog_content$1($$anchor, $$props) {
	const uid = props_id();
	push($$props, true);
	let id = prop($$props, "id", 19, () => createId(uid)), ref = prop($$props, "ref", 15, null), forceMount = prop($$props, "forceMount", 3, false), onCloseAutoFocus = prop($$props, "onCloseAutoFocus", 3, noop$1), onOpenAutoFocus = prop($$props, "onOpenAutoFocus", 3, noop$1), onEscapeKeydown = prop($$props, "onEscapeKeydown", 3, noop$1), onInteractOutside = prop($$props, "onInteractOutside", 3, noop$1), trapFocus = prop($$props, "trapFocus", 3, true), preventScroll = prop($$props, "preventScroll", 3, true), restoreScrollDelay = prop($$props, "restoreScrollDelay", 3, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"id",
		"children",
		"child",
		"ref",
		"forceMount",
		"onCloseAutoFocus",
		"onOpenAutoFocus",
		"onEscapeKeydown",
		"onInteractOutside",
		"trapFocus",
		"preventScroll",
		"restoreScrollDelay"
	]);
	const contentState = DialogContentState.create({
		id: boxWith(() => id()),
		ref: boxWith(() => ref(), (v) => ref(v))
	});
	const mergedProps = user_derived(() => mergeProps(restProps, contentState.props));
	var fragment = comment();
	var node = first_child(fragment);
	var consequent_2 = ($$anchor) => {
		{
			const focusScope = ($$anchor, $$arg0) => {
				let focusScopeProps = () => $$arg0?.().props;
				Escape_layer($$anchor, spread_props(() => get(mergedProps), {
					get enabled() {
						return contentState.root.opts.open.current;
					},
					get ref() {
						return contentState.opts.ref;
					},
					onEscapeKeydown: (e) => {
						onEscapeKeydown()(e);
						if (e.defaultPrevented) return;
						contentState.root.handleClose();
					},
					children: ($$anchor, $$slotProps) => {
						Dismissible_layer($$anchor, spread_props(() => get(mergedProps), {
							get ref() {
								return contentState.opts.ref;
							},
							get enabled() {
								return contentState.root.opts.open.current;
							},
							onInteractOutside: (e) => {
								onInteractOutside()(e);
								if (e.defaultPrevented) return;
								contentState.root.handleClose();
							},
							children: ($$anchor, $$slotProps) => {
								Text_selection_layer($$anchor, spread_props(() => get(mergedProps), {
									get ref() {
										return contentState.opts.ref;
									},
									get enabled() {
										return contentState.root.opts.open.current;
									},
									children: ($$anchor, $$slotProps) => {
										var fragment_5 = comment();
										var node_1 = first_child(fragment_5);
										var consequent_1 = ($$anchor) => {
											var fragment_6 = root_6$1();
											var node_2 = first_child(fragment_6);
											var consequent = ($$anchor) => {
												Scroll_lock($$anchor, {
													get preventScroll() {
														return preventScroll();
													},
													get restoreScrollDelay() {
														return restoreScrollDelay();
													}
												});
											};
											if_block(node_2, ($$render) => {
												if (contentState.root.opts.open.current) $$render(consequent);
											});
											var node_3 = sibling(node_2, 2);
											{
												let $0 = user_derived(() => ({
													props: mergeProps(get(mergedProps), focusScopeProps()),
													...contentState.snippetProps
												}));
												snippet(node_3, () => $$props.child, () => get($0));
											}
											append($$anchor, fragment_6);
										};
										var alternate = ($$anchor) => {
											var fragment_8 = root_8();
											var node_4 = first_child(fragment_8);
											Scroll_lock(node_4, { get preventScroll() {
												return preventScroll();
											} });
											var div = sibling(node_4, 2);
											attribute_effect(div, ($0) => ({ ...$0 }), [() => mergeProps(get(mergedProps), focusScopeProps())]);
											snippet(child(div), () => $$props.children ?? noop);
											reset(div);
											append($$anchor, fragment_8);
										};
										if_block(node_1, ($$render) => {
											if ($$props.child) $$render(consequent_1);
											else $$render(alternate, -1);
										});
										append($$anchor, fragment_5);
									},
									$$slots: { default: true }
								}));
							},
							$$slots: { default: true }
						}));
					},
					$$slots: { default: true }
				}));
			};
			Focus_scope($$anchor, {
				get ref() {
					return contentState.opts.ref;
				},
				loop: true,
				get trapFocus() {
					return trapFocus();
				},
				get enabled() {
					return contentState.root.opts.open.current;
				},
				get onOpenAutoFocus() {
					return onOpenAutoFocus();
				},
				get onCloseAutoFocus() {
					return onCloseAutoFocus();
				},
				focusScope,
				$$slots: { focusScope: true }
			});
		}
	};
	if_block(node, ($$render) => {
		if (contentState.shouldRender || forceMount()) $$render(consequent_2);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region extension/utils/common/functions/extension.ts
var BADGE_TYPES = {
	default: {
		text: "",
		color: null
	},
	error: {
		text: "error",
		color: "#FF0000"
	},
	count: {
		text: async (options) => {
			if (options.events && options.messages) return `${options.events}/${options.messages}`;
			else if (options.events) return options.events.toString();
			else if (options.messages) return options.messages.toString();
			else return await getBadgeText() === "error" ? "error" : null;
		},
		color: async (options) => {
			if (options.events && options.messages) return "#1ed2ac";
			else if (options.events) return "#009eda";
			else if (options.messages) return "#84af03";
			else return await getBadgeText() === "error" ? "error" : null;
		}
	}
};
async function setBadge(type, partialOptions = {}) {
	if (SCRIPT_TYPE !== "BACKGROUND") return false;
	const options = {
		events: 0,
		messages: 0,
		...partialOptions
	};
	const badge = { ...BADGE_TYPES[type] };
	if (typeof badge.text === "function") badge.text = await badge.text(options);
	if (typeof badge.color === "function") badge.color = await badge.color(options);
	if (!badge.text) badge.text = "";
	browser.action.setBadgeText({ text: badge.text || "" });
	if (badge.color) browser.action.setBadgeBackgroundColor({ color: badge.color });
	return true;
}
function getBadgeText() {
	if (SCRIPT_TYPE !== "BACKGROUND") return Promise.resolve(null);
	return browser.action.getBadgeText({});
}
//#endregion
//#region node_modules/serialize-error/error-constructors.js
var list = [
	EvalError,
	RangeError,
	ReferenceError,
	SyntaxError,
	TypeError,
	URIError,
	globalThis.DOMException,
	globalThis.AssertionError,
	globalThis.SystemError
].filter(Boolean).map((constructor) => [constructor.name, constructor]);
var errorConstructors = new Map(list);
//#endregion
//#region node_modules/serialize-error/index.js
var NonError = class NonError extends Error {
	name = "NonError";
	constructor(message) {
		super(NonError._prepareSuperMessage(message));
	}
	static _prepareSuperMessage(message) {
		try {
			return JSON.stringify(message);
		} catch {
			return String(message);
		}
	}
};
var commonProperties = [
	{
		property: "name",
		enumerable: false
	},
	{
		property: "message",
		enumerable: false
	},
	{
		property: "stack",
		enumerable: false
	},
	{
		property: "code",
		enumerable: true
	},
	{
		property: "cause",
		enumerable: false
	}
];
var toJsonWasCalled = /* @__PURE__ */ new WeakSet();
var toJSON = (from) => {
	toJsonWasCalled.add(from);
	const json = from.toJSON();
	toJsonWasCalled.delete(from);
	return json;
};
var getErrorConstructor = (name) => errorConstructors.get(name) ?? Error;
var destroyCircular = ({ from, seen, to, forceEnumerable, maxDepth, depth, useToJSON, serialize }) => {
	if (!to) if (Array.isArray(from)) to = [];
	else if (!serialize && isErrorLike(from)) to = new (getErrorConstructor(from.name))();
	else to = {};
	seen.push(from);
	if (depth >= maxDepth) return to;
	if (useToJSON && typeof from.toJSON === "function" && !toJsonWasCalled.has(from)) return toJSON(from);
	const continueDestroyCircular = (value) => destroyCircular({
		from: value,
		seen: [...seen],
		forceEnumerable,
		maxDepth,
		depth,
		useToJSON,
		serialize
	});
	for (const [key, value] of Object.entries(from)) {
		if (value && value instanceof Uint8Array && value.constructor.name === "Buffer") {
			to[key] = "[object Buffer]";
			continue;
		}
		if (value !== null && typeof value === "object" && typeof value.pipe === "function") {
			to[key] = "[object Stream]";
			continue;
		}
		if (typeof value === "function") continue;
		if (!value || typeof value !== "object") {
			try {
				to[key] = value;
			} catch {}
			continue;
		}
		if (!seen.includes(from[key])) {
			depth++;
			to[key] = continueDestroyCircular(from[key]);
			continue;
		}
		to[key] = "[Circular]";
	}
	for (const { property, enumerable } of commonProperties) if (typeof from[property] !== "undefined" && from[property] !== null) Object.defineProperty(to, property, {
		value: isErrorLike(from[property]) ? continueDestroyCircular(from[property]) : from[property],
		enumerable: forceEnumerable ? true : enumerable,
		configurable: true,
		writable: true
	});
	return to;
};
function serializeError(value, options = {}) {
	const { maxDepth = Number.POSITIVE_INFINITY, useToJSON = true } = options;
	if (typeof value === "object" && value !== null) return destroyCircular({
		from: value,
		seen: [],
		forceEnumerable: true,
		maxDepth,
		depth: 0,
		useToJSON,
		serialize: true
	});
	if (typeof value === "function") return `[Function: ${value.name || "anonymous"}]`;
	return value;
}
function deserializeError(value, options = {}) {
	const { maxDepth = Number.POSITIVE_INFINITY } = options;
	if (value instanceof Error) return value;
	if (isMinimumViableSerializedError(value)) return destroyCircular({
		from: value,
		seen: [],
		to: new (getErrorConstructor(value.name))(),
		maxDepth,
		depth: 0,
		serialize: false
	});
	return new NonError(value);
}
function isErrorLike(value) {
	return Boolean(value) && typeof value === "object" && "name" in value && "message" in value && "stack" in value;
}
function isMinimumViableSerializedError(value) {
	return Boolean(value) && typeof value === "object" && "message" in value && !Array.isArray(value);
}
//#endregion
//#region node_modules/@webext-core/messaging/lib/chunk-BQLFSFFZ.js
var __defProp = Object.defineProperty;
var __defProps = Object.defineProperties;
var __getOwnPropDescs = Object.getOwnPropertyDescriptors;
var __getOwnPropSymbols = Object.getOwnPropertySymbols;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __propIsEnum = Object.prototype.propertyIsEnumerable;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, {
	enumerable: true,
	configurable: true,
	writable: true,
	value
}) : obj[key] = value;
var __spreadValues = (a, b) => {
	for (var prop in b || (b = {})) if (__hasOwnProp.call(b, prop)) __defNormalProp(a, prop, b[prop]);
	if (__getOwnPropSymbols) {
		for (var prop of __getOwnPropSymbols(b)) if (__propIsEnum.call(b, prop)) __defNormalProp(a, prop, b[prop]);
	}
	return a;
};
var __spreadProps = (a, b) => __defProps(a, __getOwnPropDescs(b));
var __async = (__this, __arguments, generator) => {
	return new Promise((resolve, reject) => {
		var fulfilled = (value) => {
			try {
				step(generator.next(value));
			} catch (e) {
				reject(e);
			}
		};
		var rejected = (value) => {
			try {
				step(generator.throw(value));
			} catch (e) {
				reject(e);
			}
		};
		var step = (x) => x.done ? resolve(x.value) : Promise.resolve(x.value).then(fulfilled, rejected);
		step((generator = generator.apply(__this, __arguments)).next());
	});
};
function defineGenericMessanging(config) {
	let removeRootListener;
	let perTypeListeners = {};
	function cleanupRootListener() {
		if (Object.entries(perTypeListeners).length === 0) {
			removeRootListener?.();
			removeRootListener = void 0;
		}
	}
	let idSeq = Math.floor(Math.random() * 1e4);
	function getNextId() {
		return idSeq++;
	}
	return {
		sendMessage(type, data, ...args) {
			return __async(this, null, function* () {
				var _a2, _b, _c, _d;
				const _message = {
					id: getNextId(),
					type,
					data,
					timestamp: Date.now()
				};
				const message = (_b = yield (_a2 = config.verifyMessageData) == null ? void 0 : _a2.call(config, _message)) != null ? _b : _message;
				(_c = config.logger) == null || _c.debug(`[messaging] sendMessage {id=${message.id}} \u2500\u1405`, message, ...args);
				const response = yield config.sendMessage(message, ...args);
				const { res, err } = response != null ? response : { err: /* @__PURE__ */ new Error("No response") };
				(_d = config.logger) == null || _d.debug(`[messaging] sendMessage {id=${message.id}} \u140A\u2500`, {
					res,
					err
				});
				if (err != null) throw deserializeError(err);
				return res;
			});
		},
		onMessage(type, onReceived) {
			var _a2, _b, _c;
			if (removeRootListener == null) {
				(_a2 = config.logger) == null || _a2.debug(`[messaging] "${type}" initialized the message listener for this context`);
				removeRootListener = config.addRootListener((message) => {
					var _a3, _b2;
					if (typeof message.type != "string" || typeof message.timestamp !== "number") {
						if (config.breakError) return;
						const err = Error(`[messaging] Unknown message format, must include the 'type' & 'timestamp' fields, received: ${JSON.stringify(message)}`);
						(_a3 = config.logger) == null || _a3.error(err);
						throw err;
					}
					(_b2 = config == null ? void 0 : config.logger) == null || _b2.debug("[messaging] Received message", message);
					const listener = perTypeListeners[message.type];
					if (listener == null) return;
					const res = listener(message);
					return Promise.resolve(res).then((res2) => {
						var _a4, _b3;
						return (_b3 = (_a4 = config.verifyMessageData) == null ? void 0 : _a4.call(config, res2)) != null ? _b3 : res2;
					}).then((res2) => {
						var _a4;
						(_a4 = config == null ? void 0 : config.logger) == null || _a4.debug(`[messaging] onMessage {id=${message.id}} \u2500\u1405`, { res: res2 });
						return { res: res2 };
					}).catch((err) => {
						var _a4;
						(_a4 = config == null ? void 0 : config.logger) == null || _a4.debug(`[messaging] onMessage {id=${message.id}} \u2500\u1405`, { err });
						return { err: serializeError(err) };
					});
				});
			}
			if (perTypeListeners[type] != null) {
				const err = Error(`[messaging] In this JS context, only one listener can be setup for ${type}`);
				(_b = config.logger) == null || _b.error(err);
				throw err;
			}
			perTypeListeners[type] = onReceived;
			(_c = config.logger) == null || _c.log(`[messaging] Added listener for ${type}`);
			return () => {
				delete perTypeListeners[type];
				cleanupRootListener();
			};
		},
		removeAllListeners() {
			Object.keys(perTypeListeners).forEach((type) => {
				delete perTypeListeners[type];
			});
			cleanupRootListener();
		}
	};
}
//#endregion
//#region node_modules/@webext-core/messaging/lib/index.js
var import_browser_polyfill = /* @__PURE__ */ __toESM((/* @__PURE__ */ __commonJSMin(((exports, module) => {
	(function(global, factory) {
		if (typeof define === "function" && define.amd) define("webextension-polyfill", ["module"], factory);
		else if (typeof exports !== "undefined") factory(module);
		else {
			var mod = { exports: {} };
			factory(mod);
			global.browser = mod.exports;
		}
	})(typeof globalThis !== "undefined" ? globalThis : typeof self !== "undefined" ? self : exports, function(module$1) {
		"use strict";
		if (!globalThis.chrome?.runtime?.id) throw new Error("This script should only be loaded in a browser extension.");
		if (typeof globalThis.browser === "undefined" || Object.getPrototypeOf(globalThis.browser) !== Object.prototype) {
			const CHROME_SEND_MESSAGE_CALLBACK_NO_RESPONSE_MESSAGE = "The message port closed before a response was received.";
			const wrapAPIs = (extensionAPIs) => {
				const apiMetadata = {
					"alarms": {
						"clear": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"clearAll": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"get": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"getAll": {
							"minArgs": 0,
							"maxArgs": 0
						}
					},
					"bookmarks": {
						"create": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"get": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getChildren": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getRecent": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getSubTree": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getTree": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"move": {
							"minArgs": 2,
							"maxArgs": 2
						},
						"remove": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeTree": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"search": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"update": {
							"minArgs": 2,
							"maxArgs": 2
						}
					},
					"browserAction": {
						"disable": {
							"minArgs": 0,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"enable": {
							"minArgs": 0,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"getBadgeBackgroundColor": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getBadgeText": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getPopup": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getTitle": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"openPopup": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"setBadgeBackgroundColor": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"setBadgeText": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"setIcon": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"setPopup": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"setTitle": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						}
					},
					"browsingData": {
						"remove": {
							"minArgs": 2,
							"maxArgs": 2
						},
						"removeCache": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeCookies": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeDownloads": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeFormData": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeHistory": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeLocalStorage": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removePasswords": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removePluginData": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"settings": {
							"minArgs": 0,
							"maxArgs": 0
						}
					},
					"commands": { "getAll": {
						"minArgs": 0,
						"maxArgs": 0
					} },
					"contextMenus": {
						"remove": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeAll": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"update": {
							"minArgs": 2,
							"maxArgs": 2
						}
					},
					"cookies": {
						"get": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getAll": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getAllCookieStores": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"remove": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"set": {
							"minArgs": 1,
							"maxArgs": 1
						}
					},
					"devtools": {
						"inspectedWindow": { "eval": {
							"minArgs": 1,
							"maxArgs": 2,
							"singleCallbackArg": false
						} },
						"panels": {
							"create": {
								"minArgs": 3,
								"maxArgs": 3,
								"singleCallbackArg": true
							},
							"elements": { "createSidebarPane": {
								"minArgs": 1,
								"maxArgs": 1
							} }
						}
					},
					"downloads": {
						"cancel": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"download": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"erase": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getFileIcon": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"open": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"pause": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeFile": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"resume": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"search": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"show": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						}
					},
					"extension": {
						"isAllowedFileSchemeAccess": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"isAllowedIncognitoAccess": {
							"minArgs": 0,
							"maxArgs": 0
						}
					},
					"history": {
						"addUrl": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"deleteAll": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"deleteRange": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"deleteUrl": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getVisits": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"search": {
							"minArgs": 1,
							"maxArgs": 1
						}
					},
					"i18n": {
						"detectLanguage": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getAcceptLanguages": {
							"minArgs": 0,
							"maxArgs": 0
						}
					},
					"identity": { "launchWebAuthFlow": {
						"minArgs": 1,
						"maxArgs": 1
					} },
					"idle": { "queryState": {
						"minArgs": 1,
						"maxArgs": 1
					} },
					"management": {
						"get": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getAll": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"getSelf": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"setEnabled": {
							"minArgs": 2,
							"maxArgs": 2
						},
						"uninstallSelf": {
							"minArgs": 0,
							"maxArgs": 1
						}
					},
					"notifications": {
						"clear": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"create": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"getAll": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"getPermissionLevel": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"update": {
							"minArgs": 2,
							"maxArgs": 2
						}
					},
					"pageAction": {
						"getPopup": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getTitle": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"hide": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"setIcon": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"setPopup": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"setTitle": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						},
						"show": {
							"minArgs": 1,
							"maxArgs": 1,
							"fallbackToNoCallback": true
						}
					},
					"permissions": {
						"contains": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getAll": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"remove": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"request": {
							"minArgs": 1,
							"maxArgs": 1
						}
					},
					"runtime": {
						"getBackgroundPage": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"getPlatformInfo": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"openOptionsPage": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"requestUpdateCheck": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"sendMessage": {
							"minArgs": 1,
							"maxArgs": 3
						},
						"sendNativeMessage": {
							"minArgs": 2,
							"maxArgs": 2
						},
						"setUninstallURL": {
							"minArgs": 1,
							"maxArgs": 1
						}
					},
					"sessions": {
						"getDevices": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"getRecentlyClosed": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"restore": {
							"minArgs": 0,
							"maxArgs": 1
						}
					},
					"storage": {
						"local": {
							"clear": {
								"minArgs": 0,
								"maxArgs": 0
							},
							"get": {
								"minArgs": 0,
								"maxArgs": 1
							},
							"getBytesInUse": {
								"minArgs": 0,
								"maxArgs": 1
							},
							"remove": {
								"minArgs": 1,
								"maxArgs": 1
							},
							"set": {
								"minArgs": 1,
								"maxArgs": 1
							}
						},
						"managed": {
							"get": {
								"minArgs": 0,
								"maxArgs": 1
							},
							"getBytesInUse": {
								"minArgs": 0,
								"maxArgs": 1
							}
						},
						"sync": {
							"clear": {
								"minArgs": 0,
								"maxArgs": 0
							},
							"get": {
								"minArgs": 0,
								"maxArgs": 1
							},
							"getBytesInUse": {
								"minArgs": 0,
								"maxArgs": 1
							},
							"remove": {
								"minArgs": 1,
								"maxArgs": 1
							},
							"set": {
								"minArgs": 1,
								"maxArgs": 1
							}
						}
					},
					"tabs": {
						"captureVisibleTab": {
							"minArgs": 0,
							"maxArgs": 2
						},
						"create": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"detectLanguage": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"discard": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"duplicate": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"executeScript": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"get": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getCurrent": {
							"minArgs": 0,
							"maxArgs": 0
						},
						"getZoom": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"getZoomSettings": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"goBack": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"goForward": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"highlight": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"insertCSS": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"move": {
							"minArgs": 2,
							"maxArgs": 2
						},
						"query": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"reload": {
							"minArgs": 0,
							"maxArgs": 2
						},
						"remove": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"removeCSS": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"sendMessage": {
							"minArgs": 2,
							"maxArgs": 3
						},
						"setZoom": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"setZoomSettings": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"update": {
							"minArgs": 1,
							"maxArgs": 2
						}
					},
					"topSites": { "get": {
						"minArgs": 0,
						"maxArgs": 0
					} },
					"webNavigation": {
						"getAllFrames": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"getFrame": {
							"minArgs": 1,
							"maxArgs": 1
						}
					},
					"webRequest": { "handlerBehaviorChanged": {
						"minArgs": 0,
						"maxArgs": 0
					} },
					"windows": {
						"create": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"get": {
							"minArgs": 1,
							"maxArgs": 2
						},
						"getAll": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"getCurrent": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"getLastFocused": {
							"minArgs": 0,
							"maxArgs": 1
						},
						"remove": {
							"minArgs": 1,
							"maxArgs": 1
						},
						"update": {
							"minArgs": 2,
							"maxArgs": 2
						}
					}
				};
				if (Object.keys(apiMetadata).length === 0) throw new Error("api-metadata.json has not been included in browser-polyfill");
				/**
				* A WeakMap subclass which creates and stores a value for any key which does
				* not exist when accessed, but behaves exactly as an ordinary WeakMap
				* otherwise.
				*
				* @param {function} createItem
				*        A function which will be called in order to create the value for any
				*        key which does not exist, the first time it is accessed. The
				*        function receives, as its only argument, the key being created.
				*/
				class DefaultWeakMap extends WeakMap {
					constructor(createItem, items = void 0) {
						super(items);
						this.createItem = createItem;
					}
					get(key) {
						if (!this.has(key)) this.set(key, this.createItem(key));
						return super.get(key);
					}
				}
				/**
				* Returns true if the given object is an object with a `then` method, and can
				* therefore be assumed to behave as a Promise.
				*
				* @param {*} value The value to test.
				* @returns {boolean} True if the value is thenable.
				*/
				const isThenable = (value) => {
					return value && typeof value === "object" && typeof value.then === "function";
				};
				/**
				* Creates and returns a function which, when called, will resolve or reject
				* the given promise based on how it is called:
				*
				* - If, when called, `chrome.runtime.lastError` contains a non-null object,
				*   the promise is rejected with that value.
				* - If the function is called with exactly one argument, the promise is
				*   resolved to that value.
				* - Otherwise, the promise is resolved to an array containing all of the
				*   function's arguments.
				*
				* @param {object} promise
				*        An object containing the resolution and rejection functions of a
				*        promise.
				* @param {function} promise.resolve
				*        The promise's resolution function.
				* @param {function} promise.reject
				*        The promise's rejection function.
				* @param {object} metadata
				*        Metadata about the wrapped method which has created the callback.
				* @param {boolean} metadata.singleCallbackArg
				*        Whether or not the promise is resolved with only the first
				*        argument of the callback, alternatively an array of all the
				*        callback arguments is resolved. By default, if the callback
				*        function is invoked with only a single argument, that will be
				*        resolved to the promise, while all arguments will be resolved as
				*        an array if multiple are given.
				*
				* @returns {function}
				*        The generated callback function.
				*/
				const makeCallback = (promise, metadata) => {
					return (...callbackArgs) => {
						if (extensionAPIs.runtime.lastError) promise.reject(new Error(extensionAPIs.runtime.lastError.message));
						else if (metadata.singleCallbackArg || callbackArgs.length <= 1 && metadata.singleCallbackArg !== false) promise.resolve(callbackArgs[0]);
						else promise.resolve(callbackArgs);
					};
				};
				const pluralizeArguments = (numArgs) => numArgs == 1 ? "argument" : "arguments";
				/**
				* Creates a wrapper function for a method with the given name and metadata.
				*
				* @param {string} name
				*        The name of the method which is being wrapped.
				* @param {object} metadata
				*        Metadata about the method being wrapped.
				* @param {integer} metadata.minArgs
				*        The minimum number of arguments which must be passed to the
				*        function. If called with fewer than this number of arguments, the
				*        wrapper will raise an exception.
				* @param {integer} metadata.maxArgs
				*        The maximum number of arguments which may be passed to the
				*        function. If called with more than this number of arguments, the
				*        wrapper will raise an exception.
				* @param {boolean} metadata.singleCallbackArg
				*        Whether or not the promise is resolved with only the first
				*        argument of the callback, alternatively an array of all the
				*        callback arguments is resolved. By default, if the callback
				*        function is invoked with only a single argument, that will be
				*        resolved to the promise, while all arguments will be resolved as
				*        an array if multiple are given.
				*
				* @returns {function(object, ...*)}
				*       The generated wrapper function.
				*/
				const wrapAsyncFunction = (name, metadata) => {
					return function asyncFunctionWrapper(target, ...args) {
						if (args.length < metadata.minArgs) throw new Error(`Expected at least ${metadata.minArgs} ${pluralizeArguments(metadata.minArgs)} for ${name}(), got ${args.length}`);
						if (args.length > metadata.maxArgs) throw new Error(`Expected at most ${metadata.maxArgs} ${pluralizeArguments(metadata.maxArgs)} for ${name}(), got ${args.length}`);
						return new Promise((resolve, reject) => {
							if (metadata.fallbackToNoCallback) try {
								target[name](...args, makeCallback({
									resolve,
									reject
								}, metadata));
							} catch (cbError) {
								console.warn(`${name} API method doesn't seem to support the callback parameter, falling back to call it without a callback: `, cbError);
								target[name](...args);
								metadata.fallbackToNoCallback = false;
								metadata.noCallback = true;
								resolve();
							}
							else if (metadata.noCallback) {
								target[name](...args);
								resolve();
							} else target[name](...args, makeCallback({
								resolve,
								reject
							}, metadata));
						});
					};
				};
				/**
				* Wraps an existing method of the target object, so that calls to it are
				* intercepted by the given wrapper function. The wrapper function receives,
				* as its first argument, the original `target` object, followed by each of
				* the arguments passed to the original method.
				*
				* @param {object} target
				*        The original target object that the wrapped method belongs to.
				* @param {function} method
				*        The method being wrapped. This is used as the target of the Proxy
				*        object which is created to wrap the method.
				* @param {function} wrapper
				*        The wrapper function which is called in place of a direct invocation
				*        of the wrapped method.
				*
				* @returns {Proxy<function>}
				*        A Proxy object for the given method, which invokes the given wrapper
				*        method in its place.
				*/
				const wrapMethod = (target, method, wrapper) => {
					return new Proxy(method, { apply(targetMethod, thisObj, args) {
						return wrapper.call(thisObj, target, ...args);
					} });
				};
				let hasOwnProperty = Function.call.bind(Object.prototype.hasOwnProperty);
				/**
				* Wraps an object in a Proxy which intercepts and wraps certain methods
				* based on the given `wrappers` and `metadata` objects.
				*
				* @param {object} target
				*        The target object to wrap.
				*
				* @param {object} [wrappers = {}]
				*        An object tree containing wrapper functions for special cases. Any
				*        function present in this object tree is called in place of the
				*        method in the same location in the `target` object tree. These
				*        wrapper methods are invoked as described in {@see wrapMethod}.
				*
				* @param {object} [metadata = {}]
				*        An object tree containing metadata used to automatically generate
				*        Promise-based wrapper functions for asynchronous. Any function in
				*        the `target` object tree which has a corresponding metadata object
				*        in the same location in the `metadata` tree is replaced with an
				*        automatically-generated wrapper function, as described in
				*        {@see wrapAsyncFunction}
				*
				* @returns {Proxy<object>}
				*/
				const wrapObject = (target, wrappers = {}, metadata = {}) => {
					let cache = Object.create(null);
					return new Proxy(Object.create(target), {
						has(proxyTarget, prop) {
							return prop in target || prop in cache;
						},
						get(proxyTarget, prop, receiver) {
							if (prop in cache) return cache[prop];
							if (!(prop in target)) return;
							let value = target[prop];
							if (typeof value === "function") if (typeof wrappers[prop] === "function") value = wrapMethod(target, target[prop], wrappers[prop]);
							else if (hasOwnProperty(metadata, prop)) {
								let wrapper = wrapAsyncFunction(prop, metadata[prop]);
								value = wrapMethod(target, target[prop], wrapper);
							} else value = value.bind(target);
							else if (typeof value === "object" && value !== null && (hasOwnProperty(wrappers, prop) || hasOwnProperty(metadata, prop))) value = wrapObject(value, wrappers[prop], metadata[prop]);
							else if (hasOwnProperty(metadata, "*")) value = wrapObject(value, wrappers[prop], metadata["*"]);
							else {
								Object.defineProperty(cache, prop, {
									configurable: true,
									enumerable: true,
									get() {
										return target[prop];
									},
									set(value) {
										target[prop] = value;
									}
								});
								return value;
							}
							cache[prop] = value;
							return value;
						},
						set(proxyTarget, prop, value, receiver) {
							if (prop in cache) cache[prop] = value;
							else target[prop] = value;
							return true;
						},
						defineProperty(proxyTarget, prop, desc) {
							return Reflect.defineProperty(cache, prop, desc);
						},
						deleteProperty(proxyTarget, prop) {
							return Reflect.deleteProperty(cache, prop);
						}
					});
				};
				/**
				* Creates a set of wrapper functions for an event object, which handles
				* wrapping of listener functions that those messages are passed.
				*
				* A single wrapper is created for each listener function, and stored in a
				* map. Subsequent calls to `addListener`, `hasListener`, or `removeListener`
				* retrieve the original wrapper, so that  attempts to remove a
				* previously-added listener work as expected.
				*
				* @param {DefaultWeakMap<function, function>} wrapperMap
				*        A DefaultWeakMap object which will create the appropriate wrapper
				*        for a given listener function when one does not exist, and retrieve
				*        an existing one when it does.
				*
				* @returns {object}
				*/
				const wrapEvent = (wrapperMap) => ({
					addListener(target, listener, ...args) {
						target.addListener(wrapperMap.get(listener), ...args);
					},
					hasListener(target, listener) {
						return target.hasListener(wrapperMap.get(listener));
					},
					removeListener(target, listener) {
						target.removeListener(wrapperMap.get(listener));
					}
				});
				const onRequestFinishedWrappers = new DefaultWeakMap((listener) => {
					if (typeof listener !== "function") return listener;
					/**
					* Wraps an onRequestFinished listener function so that it will return a
					* `getContent()` property which returns a `Promise` rather than using a
					* callback API.
					*
					* @param {object} req
					*        The HAR entry object representing the network request.
					*/
					return function onRequestFinished(req) {
						listener(wrapObject(req, {}, { getContent: {
							minArgs: 0,
							maxArgs: 0
						} }));
					};
				});
				const onMessageWrappers = new DefaultWeakMap((listener) => {
					if (typeof listener !== "function") return listener;
					/**
					* Wraps a message listener function so that it may send responses based on
					* its return value, rather than by returning a sentinel value and calling a
					* callback. If the listener function returns a Promise, the response is
					* sent when the promise either resolves or rejects.
					*
					* @param {*} message
					*        The message sent by the other end of the channel.
					* @param {object} sender
					*        Details about the sender of the message.
					* @param {function(*)} sendResponse
					*        A callback which, when called with an arbitrary argument, sends
					*        that value as a response.
					* @returns {boolean}
					*        True if the wrapped listener returned a Promise, which will later
					*        yield a response. False otherwise.
					*/
					return function onMessage(message, sender, sendResponse) {
						let didCallSendResponse = false;
						let wrappedSendResponse;
						let sendResponsePromise = new Promise((resolve) => {
							wrappedSendResponse = function(response) {
								didCallSendResponse = true;
								resolve(response);
							};
						});
						let result;
						try {
							result = listener(message, sender, wrappedSendResponse);
						} catch (err) {
							result = Promise.reject(err);
						}
						const isResultThenable = result !== true && isThenable(result);
						if (result !== true && !isResultThenable && !didCallSendResponse) return false;
						const sendPromisedResult = (promise) => {
							promise.then((msg) => {
								sendResponse(msg);
							}, (error) => {
								let message;
								if (error && (error instanceof Error || typeof error.message === "string")) message = error.message;
								else message = "An unexpected error occurred";
								sendResponse({
									__mozWebExtensionPolyfillReject__: true,
									message
								});
							}).catch((err) => {
								console.error("Failed to send onMessage rejected reply", err);
							});
						};
						if (isResultThenable) sendPromisedResult(result);
						else sendPromisedResult(sendResponsePromise);
						return true;
					};
				});
				const wrappedSendMessageCallback = ({ reject, resolve }, reply) => {
					if (extensionAPIs.runtime.lastError) if (extensionAPIs.runtime.lastError.message === CHROME_SEND_MESSAGE_CALLBACK_NO_RESPONSE_MESSAGE) resolve();
					else reject(new Error(extensionAPIs.runtime.lastError.message));
					else if (reply && reply.__mozWebExtensionPolyfillReject__) reject(new Error(reply.message));
					else resolve(reply);
				};
				const wrappedSendMessage = (name, metadata, apiNamespaceObj, ...args) => {
					if (args.length < metadata.minArgs) throw new Error(`Expected at least ${metadata.minArgs} ${pluralizeArguments(metadata.minArgs)} for ${name}(), got ${args.length}`);
					if (args.length > metadata.maxArgs) throw new Error(`Expected at most ${metadata.maxArgs} ${pluralizeArguments(metadata.maxArgs)} for ${name}(), got ${args.length}`);
					return new Promise((resolve, reject) => {
						const wrappedCb = wrappedSendMessageCallback.bind(null, {
							resolve,
							reject
						});
						args.push(wrappedCb);
						apiNamespaceObj.sendMessage(...args);
					});
				};
				const staticWrappers = {
					devtools: { network: { onRequestFinished: wrapEvent(onRequestFinishedWrappers) } },
					runtime: {
						onMessage: wrapEvent(onMessageWrappers),
						onMessageExternal: wrapEvent(onMessageWrappers),
						sendMessage: wrappedSendMessage.bind(null, "sendMessage", {
							minArgs: 1,
							maxArgs: 3
						})
					},
					tabs: { sendMessage: wrappedSendMessage.bind(null, "sendMessage", {
						minArgs: 2,
						maxArgs: 3
					}) }
				};
				const settingMetadata = {
					clear: {
						minArgs: 1,
						maxArgs: 1
					},
					get: {
						minArgs: 1,
						maxArgs: 1
					},
					set: {
						minArgs: 1,
						maxArgs: 1
					}
				};
				apiMetadata.privacy = {
					network: { "*": settingMetadata },
					services: { "*": settingMetadata },
					websites: { "*": settingMetadata }
				};
				return wrapObject(extensionAPIs, staticWrappers, apiMetadata);
			};
			module$1.exports = wrapAPIs(chrome);
		} else module$1.exports = globalThis.browser;
	});
})))(), 1);
function defineExtensionMessaging(config) {
	return defineGenericMessanging(__spreadProps(__spreadValues({}, config), {
		sendMessage(message, arg) {
			if (arg == null) return import_browser_polyfill.default.runtime.sendMessage(message);
			const options = typeof arg === "number" ? { tabId: arg } : arg;
			return import_browser_polyfill.default.tabs.sendMessage(options.tabId, message, options.frameId != null ? { frameId: options.frameId } : void 0);
		},
		addRootListener(processMessage) {
			const listener = (message, sender) => {
				if (typeof message === "object") return processMessage(__spreadProps(__spreadValues({}, message), { sender }));
				else return processMessage(message);
			};
			import_browser_polyfill.default.runtime.onMessage.addListener(listener);
			return () => import_browser_polyfill.default.runtime.onMessage.removeListener(listener);
		}
	}));
}
//#endregion
//#region node_modules/@webext-core/proxy-service/lib/index.mjs
/**
* Create a proxy service that uses the message APIs to proxy function calls to the real service
* registered in the background with `registerService`.
*
* @param key The service key to listen for, must be the same string as the one used in
*   `registerService`.
*/
function createProxyService(key, config) {
	return createProxy(defineProxyMessaging(key, config));
}
function defineProxyMessaging(key, config) {
	const messaging = defineExtensionMessaging(config);
	return {
		messageKey: `proxy-service.${key}`,
		...messaging
	};
}
/**
* Create and returns a "deep" proxy. Every property that is accessed returns another proxy, and
* when a function is called at any depth, a message is sent to the background.
*/
function createProxy(messenger, path) {
	const wrapped = (() => {});
	const proxy = new Proxy(wrapped, {
		async apply(_target, _thisArg, args) {
			return await messenger.sendMessage(messenger.messageKey, {
				path,
				args
			});
		},
		get(target, propertyName, receiver) {
			if (typeof propertyName === "symbol") return Reflect.get(target, propertyName, receiver);
			return createProxy(messenger, path == null ? [propertyName] : path.concat([propertyName]));
		}
	});
	proxy[ProxyServiceSymbol] = true;
	return proxy;
}
var ProxyServiceSymbol = Symbol();
//#endregion
//#region extension/utils/services/proxy-service-keys.ts
var SOURCE_SERVICE_KEY = "source-service";
var BACKGROUND_SERVICE_KEY = "background-service";
createProxyService(SOURCE_SERVICE_KEY);
var BACKGROUND_SERVICE = createProxyService(BACKGROUND_SERVICE_KEY);
//#endregion
//#region extension/utils/common/functions/api.ts
var CUSTOM_API_ERROR = {
	NO_NETWORK: "tt-no_network",
	NO_PERMISSION: "tt-no_permission",
	CANCELLED: "tt-cancelled"
};
var FETCH_PLATFORMS = {
	tornv2: "https://api.torn.com/v2/",
	torn_direct: "https://www.torn.com/",
	yata: "https://yata.yt/",
	tornstats: "https://www.tornstats.com/",
	torntools: "https://torntools.gregork.com/",
	nukefamily: "https://nuke.family/",
	uhc: "https://tornuhc.eu/",
	stig: "https://api.no1irishstig.co.uk/",
	prometheus: "https://prombot.co.uk:8443/",
	lzpt: "https://api.lzpt.io/",
	wtf: "https://what-the-f.de/",
	tornw3b: "https://weav3r.dev/",
	ffscouter: "https://ffscouter.com/",
	laekna: "https://laekna-revive-bot.onrender.com/",
	tornintel: "https://torn-intel.com/"
};
async function fetchData(l, partialOptions = {}) {
	const options = {
		fakeResponse: false,
		section: void 0,
		id: void 0,
		selections: [],
		legacySelections: [],
		key: void 0,
		action: void 0,
		method: "GET",
		body: void 0,
		silent: false,
		succeedOnError: false,
		includeKey: false,
		relay: false,
		params: {},
		...partialOptions
	};
	if (options.relay && SCRIPT_TYPE !== "BACKGROUND") return new Promise((resolve, reject) => {
		BACKGROUND_SERVICE.fetchRelay(l, {
			...options,
			relay: false
		}).then((response) => resolve(response)).catch((error) => {
			if (error.name === "NonError") reject(JSON.parse(error.message));
			else reject(new Error(error));
		});
	});
	return new Promise(async (resolve, reject) => {
		let location;
		if (!(l in FETCH_PLATFORMS)) {
			location = Object.entries(FETCH_PLATFORMS).filter(([, value]) => l === value).map(([key]) => key).find(() => true);
			if (!location) throw new Error(`Unknown fetch platform was chosen: ${l}!`);
		} else location = l;
		let url, path, pathSections, key;
		const headers = {};
		const params = new URLSearchParams();
		switch (location) {
			case "tornv2":
				url = FETCH_PLATFORMS.tornv2;
				path = `${options.section}/${options.id || ""}`;
				params.append("selections", [...options.selections, ...options.legacySelections].join(","));
				params.append("legacy", options.legacySelections.join(","));
				params.append("key", options.key || api.torn.key);
				if (settings.apiUsage.comment) params.append("comment", settings.apiUsage.comment);
				break;
			case "torn_direct":
				url = FETCH_PLATFORMS.torn_direct;
				path = options.action;
				params.set("rfcv", getRFC());
				break;
			case "tornstats":
				url = FETCH_PLATFORMS.tornstats;
				pathSections = [
					"api",
					"v2",
					options.key || api.tornstats.key || api.torn.key
				];
				if (options.section) pathSections.push(options.section);
				if (options.id) pathSections.push(options.id);
				path = pathSections.join("/");
				break;
			case "yata":
				url = FETCH_PLATFORMS.yata;
				pathSections = [
					"api",
					"v1",
					options.section
				];
				if (options.id) pathSections.push(options.id, "");
				if (options.includeKey) key = api.yata.key;
				path = pathSections.join("/");
				break;
			case "prometheus":
				url = FETCH_PLATFORMS.prometheus;
				path = ["api", options.section].join("/");
				break;
			case "tornw3b":
				url = FETCH_PLATFORMS.tornw3b;
				path = ["api", options.section].join("/");
				break;
			case "ffscouter":
				url = FETCH_PLATFORMS.ffscouter;
				path = [
					"api",
					"v1",
					options.section
				].join("/");
				key = api.ffScouter.key;
				break;
			case "tornintel":
				url = FETCH_PLATFORMS.tornintel;
				path = ["api", options.section].join("/");
				break;
			default:
				url = FETCH_PLATFORMS[location];
				path = options.section;
				break;
		}
		if (options.includeKey) params.append("key", options.key || key || api.torn.key);
		if (options.params) for (const [key, value] of Object.entries(options.params)) params.append(key, value.toString());
		const fullUrl = `${url}${path}${params.toString() ? `?${params}` : ""}`;
		let parameters = {};
		if (options.method.toUpperCase() === "POST") {
			let body;
			if (options.body instanceof URLSearchParams) body = options.body;
			else {
				body = JSON.stringify(options.body);
				headers["content-type"] = "application/json";
			}
			if (location === "torn_direct") headers["x-requested-with"] = "XMLHttpRequest";
			parameters = {
				method: "POST",
				body
			};
		}
		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), decideTimeoutTimer(l));
		fetch(fullUrl, {
			...parameters,
			headers,
			signal: controller.signal
		}).then(async (response) => {
			let result = {};
			try {
				result = await response.clone().json();
			} catch (error) {
				if (location === "torn_direct" || location === "laekna") {
					result = await response.clone().text();
					resolve(result);
					return;
				} else {
					if (controller.signal.aborted) {
						result.success = false;
						result.error = error;
					} else if (response.status === 200) result.success = true;
					else {
						result.success = false;
						result.error = new HTTPException(response.status);
					}
					result.metadata = {
						error,
						response,
						signal: controller.signal
					};
				}
			}
			if (options.fakeResponse) result = options.fakeResponse;
			if (result.error) await handleError(result);
			else {
				if (isTornAPICall(location) && !options.silent && SCRIPT_TYPE === "BACKGROUND") {
					await getBadgeText().then(async (value) => {
						if (value === "error") await setBadge("default");
					}).catch(() => console.error("TT - Couldn't get the badge text."));
					await ttStorage.change({ api: { torn: {
						online: true,
						error: ""
					} } });
				}
				resolve(result);
			}
		}).catch((error) => handleError(error)).then(() => clearTimeout(timeoutId));
		return fullUrl;
		async function handleError(result) {
			if (options.succeedOnError) {
				resolve(result);
				return;
			}
			if (result instanceof DOMException) {
				const error = "Request cancelled because it took too long.";
				const isLocal = false;
				const code = CUSTOM_API_ERROR.CANCELLED;
				if (isTornAPICall(location) && !options.silent && SCRIPT_TYPE === "BACKGROUND") {
					await ttStorage.change({ api: { torn: {
						online: false,
						error
					} } });
					await setBadge("error");
				}
				reject({
					error,
					isLocal,
					code
				});
			} else if (result.constructor.name === "TypeError") {
				let error = result.message;
				let isLocal = false;
				let code;
				if (error === "Failed to fetch") {
					isLocal = true;
					if (SCRIPT_TYPE === "BACKGROUND" && !await hasOrigins(url)) {
						error = "Permission issues";
						code = CUSTOM_API_ERROR.NO_PERMISSION;
					} else {
						error = "Network issues";
						code = CUSTOM_API_ERROR.NO_NETWORK;
					}
				}
				if (isTornAPICall(location) && !options.silent && SCRIPT_TYPE === "BACKGROUND") {
					await ttStorage.change({ api: { torn: {
						online: false,
						error
					} } });
					await setBadge("error");
				}
				reject({
					error,
					isLocal,
					code
				});
			} else if (isTornAPICall(location)) {
				let error, online;
				if (result.error instanceof HTTPException) {
					error = result.error.toString();
					online = false;
				} else {
					error = result.error.error;
					online = result.error.code !== 9 && !(result instanceof HTTPException);
				}
				if (!options.silent && SCRIPT_TYPE === "BACKGROUND") {
					await ttStorage.change({ api: { torn: {
						online,
						error
					} } });
					await setBadge("error");
				}
				if (result.error instanceof HTTPException) reject(result.error.asObject());
				else reject(result.error);
			} else reject({ error: result.error });
		}
	});
}
function decideTimeoutTimer(location) {
	switch (location) {
		case "yata": return 30 * TO_MILLIS.SECONDS;
		default: return 10 * TO_MILLIS.SECONDS;
	}
}
function isTornAPICall(location) {
	return ["tornv2"].includes(location);
}
async function checkAPIPermission(key) {
	try {
		const { type, faction, company } = (await fetchData("tornv2", {
			section: "key",
			selections: ["info"],
			key,
			silent: true
		})).info.access;
		if (type === "Limited Access" || type === "Full Access") return {
			access: true,
			faction,
			company
		};
		else return { access: false };
	} catch (error) {
		throw error.error;
	}
}
async function changeAPIKey(key) {
	try {
		await fetchData("tornv2", {
			section: "user",
			selections: ["basic"],
			key,
			silent: true
		});
		await ttStorage.change({ api: { torn: { key } } });
		await BACKGROUND_SERVICE.initialize();
	} catch (error) {
		throw error.error;
	}
}
function hasAPIData() {
	const hasKey = !!api?.torn?.key;
	const hasError = !!api?.torn?.error && !api.torn.error.includes("Backend error") && api.torn.error !== "Network issues";
	const hasUserdata = !!(userdata && Object.keys(userdata).length);
	return hasKey && !hasError && hasUserdata;
}
async function hasOrigins(...origins) {
	origins = origins.map((origin) => origin.replaceAll("api.torn.com", "torn.com"));
	return browser.permissions.contains({ origins });
}
var HTTPException = class HTTPException {
	code;
	constructor(code) {
		this.code = code;
	}
	get message() {
		return this.code in HTTPException.codes ? HTTPException.codes[this.code] : `Unknown code (${this.code})`;
	}
	asObject() {
		return {
			code: this.code,
			message: this.message,
			http: true
		};
	}
	toString() {
		return `HTTP ${this.code}: ${this.message}`;
	}
	static get codes() {
		return {
			200: "OK",
			201: "Created",
			202: "Accepted",
			203: "Non-Authoritative Information",
			204: "No Content",
			205: "Reset Content",
			206: "Partial Content",
			300: "Multiple Choices",
			301: "Moved Permanently",
			302: "Found",
			303: "See Other",
			304: "Not Modified",
			305: "Use Proxy",
			306: "Unused",
			307: "Temporary Redirect",
			400: "Bad Request",
			401: "Unauthorized",
			402: "Payment Required",
			403: "Forbidden",
			404: "Not Found",
			405: "Method Not Allowed",
			406: "Not Acceptable",
			407: "Proxy Authentication Required",
			408: "Request Timeout",
			409: "Conflict",
			410: "Gone",
			411: "Length Required",
			412: "Precondition Required",
			413: "Request Entry Too Large",
			414: "Request-URI Too Long",
			415: "Unsupported Media Type",
			416: "Requested Range Not Satisfiable",
			417: "Expectation Failed",
			418: "I'm a teapot",
			429: "Too Many Requests",
			500: "Internal Server Error",
			501: "Not Implemented",
			502: "Bad Gateway",
			503: "Service Unavailable",
			504: "Gateway Timeout",
			505: "HTTP Version Not Supported"
		};
	}
};
//#endregion
//#region extension/utils/common/functions/torn.ts
var LINKS = {
	auction: "https://www.torn.com/amarket.php",
	bank: "https://www.torn.com/bank.php",
	bazaar: "https://www.torn.com/bazaar.php",
	bounties: "https://www.torn.com/bounties.php#!p=main",
	chain: "https://www.torn.com/factions.php?step=your#/war/chain",
	church: "https://www.torn.com/church.php",
	committee: "https://www.torn.com/committee.php",
	companies: "https://www.torn.com/companies.php",
	companyEmployees: "https://www.torn.com/companies.php#/option=employees",
	crimes: "https://www.torn.com/crimes.php",
	donator: "https://www.torn.com/donator.php",
	education: "https://www.torn.com/page.php?sid=education",
	events: "https://www.torn.com/events.php#/step=all",
	faction: "https://www.torn.com/factions.php",
	faction__ranked_war: "https://www.torn.com/factions.php?step=your&type=1#/war/rank",
	faction_oc: "https://www.torn.com/factions.php?step=your#/tab=crimes",
	gym: "https://www.torn.com/gym.php",
	home: "https://www.torn.com/index.php",
	homepage: "https://www.torn.com/index.php",
	hospital: "https://www.torn.com/hospitalview.php",
	itemmarket: "https://www.torn.com/page.php?sid=ItemMarket",
	items: "https://www.torn.com/item.php",
	items_booster: "https://www.torn.com/item.php#boosters-items",
	items_candy: "https://www.torn.com/item.php#candy-items",
	items_drug: "https://www.torn.com/item.php#drugs-items",
	items_medical: "https://www.torn.com/item.php#medical-items",
	jailview: "https://www.torn.com/jailview.php",
	jobs: "https://www.torn.com/companies.php",
	loan: "https://www.torn.com/loan.php",
	messages: "https://www.torn.com/messages.php",
	missions: "https://www.torn.com/loader.php?sid=missions",
	organizedCrimes: "https://www.torn.com/factions.php?step=your#/tab=crimes",
	pc: "https://www.torn.com/pc.php",
	points: "https://www.torn.com/page.php?sid=points",
	pointsmarket: "https://www.torn.com/pmarket.php",
	properties: "https://www.torn.com/properties.php",
	property_upkeep: "https://www.torn.com/properties.php#/p=options&tab=upkeep",
	property_vault: "https://www.torn.com/properties.php#/p=options&tab=vault",
	raceway: "https://www.torn.com/page.php?sid=racing",
	staff: "https://www.torn.com/staff.php",
	stocks: "https://www.torn.com/page.php?sid=stocks",
	trade: "https://www.torn.com/trade.php",
	travelagency: "https://www.torn.com/page.php?sid=travel"
};
var ALL_ICONS = [
	{
		id: 1,
		icon: "icon1",
		description: "Online"
	},
	{
		id: 62,
		icon: "icon62",
		description: "Idle"
	},
	{
		id: 2,
		icon: "icon2",
		description: "Offline"
	},
	{
		id: 6,
		icon: "icon6",
		description: "Male"
	},
	{
		id: 7,
		icon: "icon7",
		description: "Female"
	},
	{
		id: 87,
		icon: "icon87",
		description: "Enby"
	},
	{
		id: 72,
		icon: "icon72",
		description: "New player"
	},
	{
		id: 3,
		icon: "icon3",
		description: "Donator",
		url: LINKS.donator
	},
	{
		id: 4,
		icon: "icon4",
		description: "Subscriber",
		url: LINKS.donator
	},
	{
		id: 11,
		icon: "icon11",
		description: "Staff",
		url: LINKS.staff
	},
	{
		id: 10,
		icon: "icon10",
		description: "Committee",
		url: LINKS.committee
	},
	{
		id: 8,
		icon: "icon8",
		description: "Marriage",
		url: LINKS.church
	},
	{
		id: 5,
		icon: "icon5",
		description: "Level 100"
	},
	{
		id: 21,
		icon: "icon21",
		description: "Army job",
		url: LINKS.jobs
	},
	{
		id: 22,
		icon: "icon22",
		description: "Casino job",
		url: LINKS.jobs
	},
	{
		id: 23,
		icon: "icon23",
		description: "Medical job",
		url: LINKS.jobs
	},
	{
		id: 24,
		icon: "icon24",
		description: "Grocer job",
		url: LINKS.jobs
	},
	{
		id: 25,
		icon: "icon25",
		description: "Lawyer job",
		url: LINKS.jobs
	},
	{
		id: 26,
		icon: "icon26",
		description: "Education job",
		url: LINKS.jobs
	},
	{
		id: 73,
		icon: "icon73",
		description: "Company director",
		url: LINKS.companies
	},
	{
		id: 27,
		icon: "icon27",
		description: "Company employee",
		url: LINKS.companies
	},
	{
		id: 83,
		icon: "icon83",
		description: "Company recruit",
		url: LINKS.companies
	},
	{
		id: 74,
		icon: "icon74",
		description: "Faction leader / co-leader",
		url: LINKS.faction
	},
	{
		id: 9,
		icon: "icon9",
		description: "Faction member",
		url: LINKS.faction
	},
	{
		id: 81,
		icon: "icon81",
		description: "Faction recruit",
		url: LINKS.faction
	},
	{
		id: 75,
		icon: "icon75",
		description: "Territory war (defending)",
		url: LINKS.faction
	},
	{
		id: 76,
		icon: "icon76",
		description: "Territory war (assaulting)",
		url: LINKS.faction
	},
	{
		id: 19,
		icon: "icon19",
		description: "Education in progress",
		url: LINKS.education
	},
	{
		id: 20,
		icon: "icon20",
		description: "Education completed",
		url: LINKS.education
	},
	{
		id: 29,
		icon: "icon29",
		description: "Investment in progress",
		url: LINKS.bank
	},
	{
		id: 30,
		icon: "icon30",
		description: "Investment completed",
		url: LINKS.bank
	},
	{
		id: 31,
		icon: "icon31",
		description: "Cayman islands bank",
		url: LINKS.travelagency
	},
	{
		id: 32,
		icon: "icon32",
		description: "Property vault",
		url: LINKS.property_vault
	},
	{
		id: 33,
		icon: "icon33",
		description: "Loan",
		url: LINKS.loan
	},
	{
		id: 34,
		icon: "icon34",
		description: "Items in auction",
		url: LINKS.auction
	},
	{
		id: 35,
		icon: "icon35",
		description: "Items in bazaar",
		url: LINKS.bazaar
	},
	{
		id: 36,
		icon: "icon36",
		description: "Items in item market",
		url: LINKS.itemmarket
	},
	{
		id: 54,
		icon: "icon54",
		description: "Points market",
		url: LINKS.pointsmarket
	},
	{
		id: 38,
		icon: "icon38",
		description: "Stocks owned",
		url: LINKS.stocks
	},
	{
		id: 84,
		icon: "icon84",
		description: "Dividend collection ready",
		url: LINKS.stocks
	},
	{
		id: 37,
		icon: "icon37",
		description: "Trade in progress",
		url: LINKS.trade
	},
	{
		id: 68,
		icon: "icon68",
		description: "Reading book"
	},
	{
		id: 71,
		icon: "icon71",
		description: "Traveling",
		url: LINKS.homepage
	},
	{
		id: 17,
		icon: "icon17",
		description: "Racing in progress",
		url: LINKS.raceway
	},
	{
		id: 18,
		icon: "icon18",
		description: "Racing completed",
		url: LINKS.raceway
	},
	{
		id: 85,
		icon: "icon85",
		description: "Organized crime being planned",
		url: LINKS.faction_oc
	},
	{
		id: 86,
		icon: "icon86",
		description: "Organized crime ready",
		url: LINKS.faction_oc
	},
	{
		id: 89,
		icon: "icon89",
		description: "Organized crime recruiting",
		url: LINKS.faction_oc
	},
	{
		id: 90,
		icon: "icon90",
		description: "Organized crime completed",
		url: LINKS.faction_oc
	},
	{
		id: 13,
		icon: "icon13",
		description: "Bounty",
		url: LINKS.bounties
	},
	{
		id: 28,
		icon: "icon28",
		description: "Cashier's checks",
		url: LINKS.bank
	},
	{
		id: 55,
		icon: "icon55",
		description: "Auction high bidder",
		url: LINKS.auction
	},
	{
		id: 56,
		icon: "icon56",
		description: "Auction outbid",
		url: LINKS.auction
	},
	{
		id: 15,
		icon: "icon15",
		description: "Hospital",
		url: LINKS.hospital
	},
	{
		id: 82,
		icon: "icon82",
		description: "Hospital early discharge",
		url: LINKS.hospital
	},
	{
		id: 91,
		icon: "icon91",
		description: "Hospital radiation poisoning",
		url: LINKS.hospital
	},
	{
		id: 16,
		icon: "icon16",
		description: "Jail",
		url: LINKS.jailview
	},
	{
		id: 70,
		icon: "icon70",
		description: "Federal jail"
	},
	{
		id: 12,
		icon: "icon12",
		description: "Low life",
		url: LINKS.hospital
	},
	{
		id: 39,
		icon: "icon39",
		description: "Booster cooldown (0-6hr)",
		url: LINKS.items_booster
	},
	{
		id: 40,
		icon: "icon40",
		description: "Booster cooldown (6-12hr)",
		url: LINKS.items_booster
	},
	{
		id: 41,
		icon: "icon41",
		description: "Booster cooldown (12-18hr)",
		url: LINKS.items_booster
	},
	{
		id: 42,
		icon: "icon42",
		description: "Booster cooldown (18-24hr)",
		url: LINKS.items_booster
	},
	{
		id: 43,
		icon: "icon43",
		description: "Booster cooldown (24hr+)",
		url: LINKS.items_booster
	},
	{
		id: 44,
		icon: "icon44",
		description: "Medical cooldown (0-90m)",
		url: LINKS.items_medical
	},
	{
		id: 45,
		icon: "icon45",
		description: "Medical cooldown (90-180m)",
		url: LINKS.items_medical
	},
	{
		id: 46,
		icon: "icon46",
		description: "Medical cooldown (180m-270m)",
		url: LINKS.items_medical
	},
	{
		id: 47,
		icon: "icon47",
		description: "Medical cooldown (270-360m)",
		url: LINKS.items_medical
	},
	{
		id: 48,
		icon: "icon48",
		description: "Medical cooldown (360m+)",
		url: LINKS.items_medical
	},
	{
		id: 49,
		icon: "icon49",
		description: "Drug cooldown (0-10m)",
		url: LINKS.items_drug
	},
	{
		id: 50,
		icon: "icon50",
		description: "Drug cooldown (10-60m)",
		url: LINKS.items_drug
	},
	{
		id: 51,
		icon: "icon51",
		description: "Drug cooldown (1-2hr)",
		url: LINKS.items_drug
	},
	{
		id: 52,
		icon: "icon52",
		description: "Drug cooldown (2-5hr)",
		url: LINKS.items_drug
	},
	{
		id: 53,
		icon: "icon53",
		description: "Drug cooldown (5hr+)",
		url: LINKS.items_drug
	},
	{
		id: 57,
		icon: "icon57",
		description: "Drug addiction (1-4%)",
		url: LINKS.travelagency
	},
	{
		id: 58,
		icon: "icon58",
		description: "Drug addiction (5-9%)",
		url: LINKS.travelagency
	},
	{
		id: 59,
		icon: "icon59",
		description: "Drug addiction (10-19%)",
		url: LINKS.travelagency
	},
	{
		id: 60,
		icon: "icon60",
		description: "Drug addiction (20-29%)",
		url: LINKS.travelagency
	},
	{
		id: 61,
		icon: "icon61",
		description: "Drug addiction (30%+)",
		url: LINKS.travelagency
	},
	{
		id: 63,
		icon: "icon63",
		description: "Radiation sickness (1-17%)",
		url: LINKS.items_medical
	},
	{
		id: 64,
		icon: "icon64",
		description: "Radiation sickness (18-34%)",
		url: LINKS.items_medical
	},
	{
		id: 65,
		icon: "icon65",
		description: "Radiation sickness (35-50%)",
		url: LINKS.items_medical
	},
	{
		id: 66,
		icon: "icon66",
		description: "Radiation sickness (51-67%)",
		url: LINKS.items_medical
	},
	{
		id: 67,
		icon: "icon67",
		description: "Radiation sickness (68%+)",
		url: LINKS.items_medical
	},
	{
		id: 78,
		icon: "icon78",
		description: "Upkeep due (4-6%)",
		url: LINKS.property_upkeep
	},
	{
		id: 79,
		icon: "icon79",
		description: "Upkeep due (6-8%)",
		url: LINKS.property_upkeep
	},
	{
		id: 80,
		icon: "icon80",
		description: "Upkeep due (8%+)",
		url: LINKS.property_upkeep
	}
];
var ALL_AREAS = [
	{
		class: "home",
		text: "Home"
	},
	{
		class: "items",
		text: "Items"
	},
	{
		class: "city",
		text: "City"
	},
	{
		class: "job",
		text: "Job"
	},
	{
		class: "gym",
		text: "Gym"
	},
	{
		class: "properties",
		text: "Properties"
	},
	{
		class: "education",
		text: "Education"
	},
	{
		class: "crimes",
		text: "Crimes"
	},
	{
		class: "missions",
		text: "Missions"
	},
	{
		class: "newspaper",
		text: "Newspaper"
	},
	{
		class: "jail",
		text: "Jail"
	},
	{
		class: "hospital",
		text: "Hospital"
	},
	{
		class: "casino",
		text: "Casino"
	},
	{
		class: "forums",
		text: "Forums"
	},
	{
		class: "hall_of_fame",
		text: "Hall of Fame"
	},
	{
		class: "faction",
		text: "My Faction"
	},
	{
		class: "recruit_citizens",
		text: "Recruit Citizens"
	},
	{
		class: "competitions",
		text: "Competitions"
	},
	{
		class: "community_events",
		text: "Community Events"
	}
];
var CASINO_GAMES = [
	"slots",
	"roulette",
	"high-low",
	"keno",
	"craps",
	"bookie",
	"lottery",
	"blackjack",
	"poker",
	"r-roulete",
	"spin-the-wheel"
];
[
	{
		id: 1,
		reason: "Admin"
	},
	{
		id: 4,
		reason: "NPC"
	},
	{
		id: 7,
		reason: "NPC"
	},
	{
		id: 9,
		reason: "NPC"
	},
	{
		id: 10,
		reason: "NPC"
	},
	{
		id: 15,
		reason: "NPC"
	},
	{
		id: 17,
		reason: "NPC"
	},
	{
		id: 19,
		reason: "NPC"
	},
	{
		id: 20,
		reason: "NPC"
	},
	{
		id: 21,
		reason: "NPC"
	}
].map(({ id }) => id);
var CHAIN_BONUSES = [
	10,
	25,
	50,
	100,
	250,
	500,
	1e3,
	2500,
	5e3,
	1e4,
	25e3,
	5e4,
	1e5
];
function getNextChainBonus(current) {
	return CHAIN_BONUSES.find((bonus) => bonus > current);
}
function isSellable(id) {
	if (!torndata?.itemsMap) return true;
	const item = torndata.itemsMap[id];
	return item && !["Book", "Unused"].includes(item.type) && ![
		373,
		374,
		375,
		376,
		472,
		473,
		474,
		475,
		476,
		477,
		478,
		583,
		584,
		585,
		820,
		920,
		1003,
		1004,
		1005,
		1006,
		1007,
		1008,
		1009,
		1010,
		1011,
		1149
	].includes(parseInt(id.toString()));
}
function getRFC() {
	const rfc = getCookie("rfc_v");
	if (!rfc) for (const cookie of document.cookie.split("; ")) {
		const parts = cookie.split("=");
		if (parts[0] === "rfc_v") return parts[1];
	}
	return rfc;
}
function isDividendStock(id) {
	let _id;
	if (typeof id === "number") _id = id;
	else if (isIntNumber(id)) _id = parseInt(id);
	else return false;
	return [
		1,
		4,
		5,
		6,
		7,
		9,
		10,
		12,
		15,
		16,
		17,
		18,
		19,
		22,
		24,
		27,
		28,
		29,
		31,
		32,
		33,
		35
	].includes(_id);
}
function getRequiredStocks(required, increment) {
	return (2 ** increment - 1) * required;
}
function getStockIncrement(required, stocks) {
	return Math.log2(Math.floor(stocks / required) + 1);
}
function getStockReward(reward, increment) {
	let value;
	if (reward.startsWith("$")) value = formatNumber(parseInt(reward.replace("$", "").replaceAll(",", "")) * increment, { currency: true });
	else if (reward.match(/^\d+x? /i)) {
		const splitBenefit = reward.split(" ");
		const hasX = splitBenefit[0].endsWith("x");
		const amount = parseInt(splitBenefit.shift().replace("x", "")) * increment;
		const item = splitBenefit.join(" ");
		value = `${formatNumber(amount)}${hasX ? "x" : ""} ${item}`;
	} else value = "Unknown, please report this!";
	return value;
}
function getRewardValue(reward) {
	let value;
	if (reward.startsWith("$")) value = parseInt(reward.replace("$", "").replaceAll(",", ""));
	else if (reward.match(/^\d+x? /i)) {
		const rewardItem = reward.split(" ").slice(1).join(" ");
		const item = torndata.items.find(({ name }) => name === rewardItem);
		if (item) value = item ? item.value.market_price : -1;
		else {
			let prices;
			switch (rewardItem) {
				case "Ammunition Pack": break;
				case "Clothing Cache":
					prices = [
						1057,
						1112,
						1113,
						1114,
						1115,
						1116,
						1117
					].map((id) => torndata.itemsMap[id].value.market_price);
					break;
				case "Random Property":
					prices = torndata.properties.map((property) => property.cost).filter((price) => !!price).map((price) => price * .75);
					break;
				case "points":
					value = torndata.stats.points_averagecost * 100;
					break;
				case "happiness":
				case "energy":
				case "nerve": break;
				default:
					value = -1;
					break;
			}
			if (prices !== void 0) value = prices.reduce((a, b) => a + b, 0) / prices.length;
		}
	} else value = -1;
	return value;
}
function getStockBoughtPrice(stock) {
	const boughtTotal = Object.values(stock.transactions).reduce((prev, trans) => prev + trans.price * trans.shares, 0);
	return {
		boughtTotal,
		boughtPrice: boughtTotal / stock.shares
	};
}
var CUSTOM_LINKS_PRESET = {
	"Auction House": { link: "https://www.torn.com/amarket.php" },
	"Bazaar : Management": { link: "https://www.torn.com/bazaar.php#/manage" },
	"Christmas Town : Maps": { link: "https://www.torn.com/christmas_town.php#/mymaps" },
	"Faction : Armory": { link: "https://www.torn.com/factions.php?step=your#/tab=armoury" },
	"Faction : Organized Crimes": { link: "https://www.torn.com/factions.php?step=your#/tab=crimes" },
	"Item Market": { link: "https://www.torn.com/page.php?sid=ItemMarket" },
	Museum: { link: "https://www.torn.com/museum.php" },
	Pharmacy: { link: "https://www.torn.com/shops.php?step=pharmacy" },
	"Points Market": { link: "https://www.torn.com/pmarket.php" },
	Raceway: { link: "https://www.torn.com/page.php?sid=racing" },
	"Travel Agency": { link: "https://www.torn.com/page.php?sid=travel" }
};
var HIGHLIGHT_PLACEHOLDERS = [{
	name: "$player",
	value: () => userdata?.profile?.name ?? null,
	description: "Your player name."
}];
var CHAT_TITLE_COLORS = {
	blue: ["rgb(10,60,173)", "rgb(22,109,236)"],
	brown: ["rgb(109,53,4)", "rgb(146,69,4)"],
	orange: ["rgb(227,130,5)", "rgb(234,164,50)"],
	purple: ["rgb(94,7,119)", "rgb(184,9,241)"],
	red: ["rgb(123,4,4)", "rgb(255,3,3)"]
};
var TORNTOOLS_FORUM_POST = "https://www.torn.com/forums.php#/p=threads&f=67&t=16243863";
//#endregion
//#region extension/svelte/components/ui/spinner/spinner.svelte
function Spinner($$anchor, $$props) {
	push($$props, true);
	let role = prop($$props, "role", 3, "status"), ariaLabel = prop($$props, "aria-label", 3, "Loading"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"class",
		"role",
		"name",
		"color",
		"stroke",
		"aria-label"
	]);
	{
		let $0 = user_derived(() => $$props.name === null ? void 0 : $$props.name);
		let $1 = user_derived(() => $$props.color === null ? void 0 : $$props.color);
		let $2 = user_derived(() => $$props.stroke === null ? void 0 : $$props.stroke);
		let $3 = user_derived(() => cn("size-4 animate-spin", $$props.class));
		Spinner$1($$anchor, spread_props({
			get role() {
				return role();
			},
			get name() {
				return get($0);
			},
			get color() {
				return get($1);
			},
			get stroke() {
				return get($2);
			},
			get "aria-label"() {
				return ariaLabel();
			},
			get class() {
				return get($3);
			}
		}, () => restProps));
	}
	pop();
}
//#endregion
//#region extension/svelte/components/ui/badge/helper.ts
var badgeVariants = tv({
	base: "h-5 gap-1 rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium transition-all has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&>svg]:size-3! focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive group/badge inline-flex w-fit shrink-0 items-center justify-center overflow-hidden whitespace-nowrap transition-colors focus-visible:ring-[3px] [&>svg]:pointer-events-none",
	variants: { variant: {
		default: "bg-primary text-primary-foreground [a]:hover:bg-primary/80",
		secondary: "bg-secondary text-secondary-foreground [a]:hover:bg-secondary/80",
		destructive: "bg-destructive/10 [a]:hover:bg-destructive/20 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 text-destructive dark:bg-destructive/20",
		outline: "border-border text-foreground [a]:hover:bg-muted [a]:hover:text-muted-foreground",
		ghost: "hover:bg-muted hover:text-muted-foreground dark:hover:bg-muted/50",
		link: "text-primary underline-offset-4 hover:underline"
	} },
	defaultVariants: { variant: "default" }
});
//#endregion
//#region extension/svelte/components/ui/badge/badge.svelte
function Badge($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), variant = prop($$props, "variant", 3, "default"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"href",
		"class",
		"variant",
		"children"
	]);
	var fragment = comment();
	element(first_child(fragment), () => $$props.href ? "a" : "span", false, ($$element, $$anchor) => {
		bind_this($$element, ($$value) => ref($$value), () => ref());
		attribute_effect($$element, ($0) => ({
			"data-slot": "badge",
			href: $$props.href,
			class: $0,
			...restProps
		}), [() => cn(badgeVariants({ variant: variant() }), $$props.class)]);
		var fragment_1 = comment();
		snippet(first_child(fragment_1), () => $$props.children ?? noop);
		append($$anchor, fragment_1);
	});
	append($$anchor, fragment);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/textarea/textarea.svelte
var root$10 = from_html(`<textarea></textarea>`);
function Textarea($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), value = prop($$props, "value", 15), dataSlot = prop($$props, "data-slot", 3, "textarea"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"value",
		"class",
		"data-slot"
	]);
	var textarea = root$10();
	remove_textarea_child(textarea);
	attribute_effect(textarea, ($0) => ({
		"data-slot": dataSlot(),
		class: $0,
		...restProps
	}), [() => cn("border-input dark:bg-input/30 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 disabled:bg-input/50 dark:disabled:bg-input/80 rounded-lg border bg-transparent px-2.5 py-2 text-base transition-colors focus-visible:ring-3 aria-invalid:ring-3 md:text-sm placeholder:text-muted-foreground flex field-sizing-fixed min-h-16 w-full outline-none disabled:cursor-not-allowed disabled:opacity-50", $$props.class)]);
	bind_this(textarea, ($$value) => ref($$value), () => ref());
	bind_value(textarea, value);
	append($$anchor, textarea);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/dialog/dialog.svelte
function Dialog($$anchor, $$props) {
	push($$props, true);
	let open = prop($$props, "open", 15, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"open"
	]);
	var fragment = comment();
	component(first_child(fragment), () => Dialog$1, ($$anchor, DialogPrimitive_Root) => {
		DialogPrimitive_Root($$anchor, spread_props(() => restProps, {
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
//#region node_modules/phosphor-svelte/lib/X.svelte
var root_2$1 = from_svg(`<path d="M208.49,191.51a12,12,0,0,1-17,17L128,145,64.49,208.49a12,12,0,0,1-17-17L111,128,47.51,64.49a12,12,0,0,1,17-17L128,111l63.51-63.52a12,12,0,0,1,17,17L145,128Z"></path>`);
var root_3 = from_svg(`<path d="M216,56V200a16,16,0,0,1-16,16H56a16,16,0,0,1-16-16V56A16,16,0,0,1,56,40H200A16,16,0,0,1,216,56Z" opacity="0.2"></path><path d="M205.66,194.34a8,8,0,0,1-11.32,11.32L128,139.31,61.66,205.66a8,8,0,0,1-11.32-11.32L116.69,128,50.34,61.66A8,8,0,0,1,61.66,50.34L128,116.69l66.34-66.35a8,8,0,0,1,11.32,11.32L139.31,128Z"></path>`, 1);
var root_4 = from_svg(`<path d="M208,32H48A16,16,0,0,0,32,48V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V48A16,16,0,0,0,208,32ZM181.66,170.34a8,8,0,0,1-11.32,11.32L128,139.31,85.66,181.66a8,8,0,0,1-11.32-11.32L116.69,128,74.34,85.66A8,8,0,0,1,85.66,74.34L128,116.69l42.34-42.35a8,8,0,0,1,11.32,11.32L139.31,128Z"></path>`);
var root_5$1 = from_svg(`<path d="M204.24,195.76a6,6,0,1,1-8.48,8.48L128,136.49,60.24,204.24a6,6,0,0,1-8.48-8.48L119.51,128,51.76,60.24a6,6,0,0,1,8.48-8.48L128,119.51l67.76-67.75a6,6,0,0,1,8.48,8.48L136.49,128Z"></path>`);
var root_6 = from_svg(`<path d="M205.66,194.34a8,8,0,0,1-11.32,11.32L128,139.31,61.66,205.66a8,8,0,0,1-11.32-11.32L116.69,128,50.34,61.66A8,8,0,0,1,61.66,50.34L128,116.69l66.34-66.35a8,8,0,0,1,11.32,11.32L139.31,128Z"></path>`);
var root_7 = from_svg(`<path d="M202.83,197.17a4,4,0,0,1-5.66,5.66L128,133.66,58.83,202.83a4,4,0,0,1-5.66-5.66L122.34,128,53.17,58.83a4,4,0,0,1,5.66-5.66L128,122.34l69.17-69.17a4,4,0,1,1,5.66,5.66L133.66,128Z"></path>`);
var root$9 = from_svg(`<svg><!><rect width="256" height="256" fill="none"></rect><!></svg>`);
function X($$anchor, $$props) {
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
	var svg = root$9();
	attribute_effect(svg, ($0, $1) => ({
		xmlns: "http://www.w3.org/2000/svg",
		role: "img",
		width: get(size),
		height: get(size),
		fill: get(color),
		transform: get(mirrored) ? "scale(-1, 1)" : void 0,
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
		append($$anchor, root_2$1());
	};
	var consequent_2 = ($$anchor) => {
		var fragment_1 = root_3();
		next();
		append($$anchor, fragment_1);
	};
	var consequent_3 = ($$anchor) => {
		append($$anchor, root_4());
	};
	var consequent_4 = ($$anchor) => {
		append($$anchor, root_5$1());
	};
	var consequent_5 = ($$anchor) => {
		append($$anchor, root_6());
	};
	var consequent_6 = ($$anchor) => {
		append($$anchor, root_7());
	};
	var alternate = ($$anchor) => {
		var text$2 = text();
		text$2.nodeValue = (console.error("Unsupported icon weight. Choose from \"thin\", \"light\", \"regular\", \"bold\", \"fill\", or \"duotone\"."), "");
		append($$anchor, text$2);
	};
	if_block(node_2, ($$render) => {
		if (get(weight) === "bold") $$render(consequent_1);
		else if (get(weight) === "duotone") $$render(consequent_2, 1);
		else if (get(weight) === "fill") $$render(consequent_3, 2);
		else if (get(weight) === "light") $$render(consequent_4, 3);
		else if (get(weight) === "regular") $$render(consequent_5, 4);
		else if (get(weight) === "thin") $$render(consequent_6, 5);
		else $$render(alternate, -1);
	});
	reset(svg);
	append($$anchor, svg);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/dialog/dialog-portal.svelte
function Dialog_portal($$anchor, $$props) {
	let restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy"
	]);
	var fragment = comment();
	component(first_child(fragment), () => Portal, ($$anchor, DialogPrimitive_Portal) => {
		DialogPrimitive_Portal($$anchor, spread_props(() => restProps));
	});
	append($$anchor, fragment);
}
//#endregion
//#region extension/svelte/components/ui/dialog/dialog-content.svelte
var root_5 = from_html(`<!> <span class="sr-only">Close</span>`, 1);
var root_2 = from_html(`<!> <!>`, 1);
var root_1 = from_html(`<!> <!>`, 1);
function Dialog_content($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), showCloseButton = prop($$props, "showCloseButton", 3, true), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"portalProps",
		"children",
		"showCloseButton"
	]);
	Dialog_portal($$anchor, spread_props(() => $$props.portalProps, {
		children: ($$anchor, $$slotProps) => {
			var fragment_1 = root_1();
			var node = first_child(fragment_1);
			component(node, () => Dialog_overlay, ($$anchor, Dialog_Overlay) => {
				Dialog_Overlay($$anchor, {});
			});
			var node_1 = sibling(node, 2);
			{
				let $0 = user_derived(() => cn("bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 ring-foreground/10 grid max-w-[calc(100%-2rem)] gap-4 rounded-xl p-4 text-sm ring-1 duration-100 sm:max-w-sm fixed top-1/2 left-1/2 z-50 w-full -translate-x-1/2 -translate-y-1/2 outline-none", $$props.class));
				component(node_1, () => Dialog_content$1, ($$anchor, DialogPrimitive_Content) => {
					DialogPrimitive_Content($$anchor, spread_props({
						"data-slot": "dialog-content",
						get class() {
							return get($0);
						}
					}, () => restProps, {
						get ref() {
							return ref();
						},
						set ref($$value) {
							ref($$value);
						},
						children: ($$anchor, $$slotProps) => {
							var fragment_2 = root_2();
							var node_2 = first_child(fragment_2);
							snippet(node_2, () => $$props.children ?? noop);
							var node_3 = sibling(node_2, 2);
							var consequent = ($$anchor) => {
								var fragment_3 = comment();
								var node_4 = first_child(fragment_3);
								{
									const child = ($$anchor, $$arg0) => {
										let props = () => $$arg0?.().props;
										Button($$anchor, spread_props({
											variant: "ghost",
											class: "absolute top-2 right-2",
											size: "icon-sm"
										}, props, {
											children: ($$anchor, $$slotProps) => {
												var fragment_5 = root_5();
												X(first_child(fragment_5), {});
												next(2);
												append($$anchor, fragment_5);
											},
											$$slots: { default: true }
										}));
									};
									component(node_4, () => Dialog_close, ($$anchor, DialogPrimitive_Close) => {
										DialogPrimitive_Close($$anchor, {
											"data-slot": "dialog-close",
											child,
											$$slots: { child: true }
										});
									});
								}
								append($$anchor, fragment_3);
							};
							if_block(node_3, ($$render) => {
								if (showCloseButton()) $$render(consequent);
							});
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
//#region extension/svelte/components/ui/dialog/dialog-description.svelte
function Dialog_description($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	{
		let $0 = user_derived(() => cn("text-muted-foreground *:[a]:hover:text-foreground text-sm *:[a]:underline *:[a]:underline-offset-3", $$props.class));
		component(node, () => Dialog_description$1, ($$anchor, DialogPrimitive_Description) => {
			DialogPrimitive_Description($$anchor, spread_props({
				"data-slot": "dialog-description",
				get class() {
					return get($0);
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
//#region extension/svelte/components/ui/dialog/dialog-footer.svelte
var root$8 = from_html(`<div><!> <!></div>`);
function Dialog_footer($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), showCloseButton = prop($$props, "showCloseButton", 3, false), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children",
		"showCloseButton"
	]);
	var div = root$8();
	attribute_effect(div, ($0) => ({
		"data-slot": "dialog-footer",
		class: $0,
		...restProps
	}), [() => cn("bg-muted/50 -mx-4 -mb-4 rounded-b-xl border-t p-4 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end", $$props.class)]);
	var node = child(div);
	snippet(node, () => $$props.children ?? noop);
	var node_1 = sibling(node, 2);
	var consequent = ($$anchor) => {
		var fragment = comment();
		var node_2 = first_child(fragment);
		{
			const child = ($$anchor, $$arg0) => {
				let props = () => $$arg0?.().props;
				Button($$anchor, spread_props({ variant: "outline" }, props, {
					children: ($$anchor, $$slotProps) => {
						next();
						append($$anchor, text("Close"));
					},
					$$slots: { default: true }
				}));
			};
			component(node_2, () => Dialog_close, ($$anchor, DialogPrimitive_Close) => {
				DialogPrimitive_Close($$anchor, {
					child,
					$$slots: { child: true }
				});
			});
		}
		append($$anchor, fragment);
	};
	if_block(node_1, ($$render) => {
		if (showCloseButton()) $$render(consequent);
	});
	reset(div);
	bind_this(div, ($$value) => ref($$value), () => ref());
	append($$anchor, div);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/dialog/dialog-header.svelte
var root$7 = from_html(`<div><!></div>`);
function Dialog_header($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children"
	]);
	var div = root$7();
	attribute_effect(div, ($0) => ({
		"data-slot": "dialog-header",
		class: $0,
		...restProps
	}), [() => cn("gap-2 flex flex-col", $$props.class)]);
	snippet(child(div), () => $$props.children ?? noop);
	reset(div);
	bind_this(div, ($$value) => ref($$value), () => ref());
	append($$anchor, div);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/dialog/dialog-overlay.svelte
function Dialog_overlay($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	{
		let $0 = user_derived(() => cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 isolate z-50", $$props.class));
		component(node, () => Dialog_overlay$1, ($$anchor, DialogPrimitive_Overlay) => {
			DialogPrimitive_Overlay($$anchor, spread_props({
				"data-slot": "dialog-overlay",
				get class() {
					return get($0);
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
//#region extension/svelte/components/ui/dialog/dialog-title.svelte
function Dialog_title($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class"
	]);
	var fragment = comment();
	var node = first_child(fragment);
	{
		let $0 = user_derived(() => cn("text-base leading-none font-medium", $$props.class));
		component(node, () => Dialog_title$1, ($$anchor, DialogPrimitive_Title) => {
			DialogPrimitive_Title($$anchor, spread_props({
				"data-slot": "dialog-title",
				get class() {
					return get($0);
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
//#region extension/svelte/components/ui/card/card.svelte
var root$6 = from_html(`<div><!></div>`);
function Card($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), size = prop($$props, "size", 3, "default"), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children",
		"size"
	]);
	var div = root$6();
	attribute_effect(div, ($0) => ({
		"data-slot": "card",
		"data-size": size(),
		class: $0,
		...restProps
	}), [() => cn("ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl py-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:py-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl group/card flex flex-col", $$props.class)]);
	snippet(child(div), () => $$props.children ?? noop);
	reset(div);
	bind_this(div, ($$value) => ref($$value), () => ref());
	append($$anchor, div);
	pop();
}
from_html(`<div><!></div>`);
//#endregion
//#region extension/svelte/components/ui/card/card-content.svelte
var root$4 = from_html(`<div><!></div>`);
function Card_content($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children"
	]);
	var div = root$4();
	attribute_effect(div, ($0) => ({
		"data-slot": "card-content",
		class: $0,
		...restProps
	}), [() => cn("px-4 group-data-[size=sm]/card:px-3", $$props.class)]);
	snippet(child(div), () => $$props.children ?? noop);
	reset(div);
	bind_this(div, ($$value) => ref($$value), () => ref());
	append($$anchor, div);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/card/card-description.svelte
var root$3 = from_html(`<p><!></p>`);
function Card_description($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children"
	]);
	var p = root$3();
	attribute_effect(p, ($0) => ({
		"data-slot": "card-description",
		class: $0,
		...restProps
	}), [() => cn("text-muted-foreground text-sm", $$props.class)]);
	snippet(child(p), () => $$props.children ?? noop);
	reset(p);
	bind_this(p, ($$value) => ref($$value), () => ref());
	append($$anchor, p);
	pop();
}
from_html(`<div><!></div>`);
//#endregion
//#region extension/svelte/components/ui/card/card-header.svelte
var root$1 = from_html(`<div><!></div>`);
function Card_header($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children"
	]);
	var div = root$1();
	attribute_effect(div, ($0) => ({
		"data-slot": "card-header",
		class: $0,
		...restProps
	}), [() => cn("gap-1 rounded-t-xl px-4 group-data-[size=sm]/card:px-3 [.border-b]:pb-4 group-data-[size=sm]/card:[.border-b]:pb-3 group/card-header @container/card-header grid auto-rows-min items-start has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto]", $$props.class)]);
	snippet(child(div), () => $$props.children ?? noop);
	reset(div);
	bind_this(div, ($$value) => ref($$value), () => ref());
	append($$anchor, div);
	pop();
}
//#endregion
//#region extension/svelte/components/ui/card/card-title.svelte
var root = from_html(`<div><!></div>`);
function Card_title($$anchor, $$props) {
	push($$props, true);
	let ref = prop($$props, "ref", 15, null), restProps = rest_props($$props, [
		"$$slots",
		"$$events",
		"$$legacy",
		"ref",
		"class",
		"children"
	]);
	var div = root();
	attribute_effect(div, ($0) => ({
		"data-slot": "card-title",
		class: $0,
		...restProps
	}), [() => cn("font-heading text-base leading-snug font-medium group-data-[size=sm]/card:text-sm", $$props.class)]);
	snippet(child(div), () => $$props.children ?? noop);
	reset(div);
	bind_this(div, ($$value) => ref($$value), () => ref());
	append($$anchor, div);
	pop();
}
//#endregion
export { isSellable as A, getNextChainBonus as C, getStockIncrement as D, getStockBoughtPrice as E, hasAPIData as F, BACKGROUND_SERVICE as I, changeAPIKey as M, checkAPIPermission as N, getStockReward as O, fetchData as P, TORNTOOLS_FORUM_POST as S, getRewardValue as T, CASINO_GAMES as _, Card as a, HIGHLIGHT_PLACEHOLDERS as b, Dialog_footer as c, Dialog as d, Textarea as f, ALL_ICONS as g, ALL_AREAS as h, Card_content as i, FETCH_PLATFORMS as j, isDividendStock as k, Dialog_description as l, Spinner as m, Card_header as n, Dialog_title as o, Badge as p, Card_description as r, Dialog_header as s, Card_title as t, Dialog_content as u, CHAT_TITLE_COLORS as v, getRequiredStocks as w, LINKS as x, CUSTOM_LINKS_PRESET as y };

//# sourceMappingURL=card-CykqZuMp.js.map