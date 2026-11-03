// JavaScriptCore's C API has ECMAScript builtins, without browser Web APIs.
// These standard Web API shims are isolated from all page JavaScript contexts.
import './url.js';
import 'core-js/actual/atob.js';
import 'core-js/actual/btoa.js';
import 'fast-text-encoding';
globalThis.self = globalThis;
if (typeof globalThis.console === 'undefined') globalThis.console = { log(){}, warn(){}, error(){}, info(){} };
const timers = new Map();
let timerId = 0;
globalThis.setTimeout = fn => { const id = ++timerId; timers.set(id, fn); return id; };
globalThis.clearTimeout = id => timers.delete(id);
