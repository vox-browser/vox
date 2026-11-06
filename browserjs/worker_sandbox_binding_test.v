module browserjs

import dom
import fetch
import html
import http
import platform
import time

fn test_worker_sandbox_can_remove_host_globals_and_acknowledge_on_a_port() {
	for kind in [html.WorkerType.classic, .module_] {
		url := dom.URL{ value: 'https://worker-sandbox.test/entry.js' }
		transport := &fetch.FetchHost{
			perform: fn (_ &fetch.Request) !&fetch.Response {
				mut response := fetch.Response.create()
				response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
				response.set_body_bytes('// worker entry'.bytes())
				return response
			}
		}
		mut agent := WorkerAgentRuntime.create(url, html.WorkerOptions{ type_: kind }, html.SerializedEnvironmentSettingsObject{
			creation_url: url
			api_base_url: url
			origin:       url.origin()
			global:       html.SerializedWindow{
				associated_document: html.SerializedDocument{
					url:                                        url
					relevant_settings_object_is_secure_context: true
				}
			}
		}, 12, transport)!
		defer { agent.close() }
		assert agent.runtime.evaluate_host('typeof __ladybirdSerializeURLText')! == 'undefined'
		agent.load_entry()!
		assert agent.state() == .ready
		assert agent.runtime.evaluate_host('new URL("../value","https://worker-sandbox.test/a/").href')! == 'https://worker-sandbox.test/value'
		if kind == .classic { continue }
		agent.runtime.evaluate_host(r'
const sandboxChannel = new MessageChannel();
const sandboxSend = sandboxChannel.port2.postMessage.bind(sandboxChannel.port2);
const sandboxSchedule = setTimeout.bind(globalThis);
let sandboxAcknowledgement = "pending";
sandboxChannel.port1.onmessage = event => { sandboxAcknowledgement = event.data; };
const sandboxAllowed = new Set([
 "Object","Function","Array","Number","BigInt","Boolean","String","Symbol",
 "Date","RegExp","Error","EvalError","RangeError","ReferenceError","SyntaxError",
 "TypeError","URIError","AggregateError","Math","JSON","Reflect","Proxy","Promise",
 "Map","Set","WeakMap","WeakSet","WeakRef","FinalizationRegistry","ArrayBuffer",
 "SharedArrayBuffer","Atomics","DataView","Int8Array","Uint8Array","Uint8ClampedArray",
 "Int16Array","Uint16Array","Int32Array","Uint32Array","Float16Array","Float32Array",
 "Float64Array","BigInt64Array","BigUint64Array","Intl","Iterator","eval",
 "parseInt","parseFloat","isNaN","isFinite","decodeURI","decodeURIComponent",
 "encodeURI","encodeURIComponent","escape","unescape","Infinity","NaN","undefined",
 "globalThis"
]);
for (let target=globalThis;target!==null&&target!==Object.prototype;target=Object.getPrototypeOf(target)) {
 for (const key of Reflect.ownKeys(target)) {
  if (typeof key==="string"&&sandboxAllowed.has(key)) continue;
  try { Reflect.set(target,key,undefined); } catch {}
  Reflect.deleteProperty(target,key);
  const descriptor=Object.getOwnPropertyDescriptor(target,key);
  if (descriptor!==undefined&&!("value" in descriptor&&descriptor.value===undefined))
   throw new Error("Host global cannot be removed: "+String(key));
 }
}
Object.freeze(globalThis);
sandboxSchedule(()=>sandboxSend("ready"),0);
')!
		deadline := time.sys_mono_now() + 2 * time.second
		for agent.runtime.evaluate_host('sandboxAcknowledgement')! == 'pending' && time.sys_mono_now() < deadline {
			agent.process()
			platform.pump_native_events(0.001)
		}
		assert agent.runtime.evaluate_host('sandboxAcknowledgement')! == 'ready'
		assert agent.runtime.evaluate_host('Object.isFrozen(globalThis)&&typeof URL==="undefined"&&typeof setTimeout==="undefined"')! == 'true'
		assert agent.environment.settings.realm().reported_exceptions.len == 0
	}
}
