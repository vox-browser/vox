module browserjs

import dom
import fetch
import html
import http
import platform
import time

fn test_native_dom_exception_and_event_callbacks_do_not_add_global_properties() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host(r'
 const hidden=["__ladybirdDOMExceptionConstruct","__ladybirdDOMExceptionGet","__ladybirdEvent","__ladybirdEventFactory","__ladybirdEventDefineTrusted"];
 hidden.every(name=>!Object.hasOwn(globalThis,name));
 ')! == 'true'
	assert runtime.evaluate_host(r'
 for(const name of hidden)Object.defineProperty(globalThis,name,{value(){throw Error("author helper")},configurable:true});
 const exception=new DOMException("native message","AbortError"),target=new EventTarget(),event=new Event("native",{cancelable:true});let hits=0;
 target.addEventListener("native",value=>{if(value===event)hits++;value.preventDefault()});
 exception.message==="native message"&&exception.name==="AbortError"&&exception.code===20&&target.dispatchEvent(event)===false&&event.defaultPrevented&&hits===1;
 ')! == 'true'
}

fn test_worker_module_import_helpers_are_private_and_ignore_author_global_properties() {
	url := dom.URL{ value: 'https://private-worker.test/entry.js' }
	transport := &fetch.FetchHost{perform: fn (request &fetch.Request) !&fetch.Response {
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{name: 'Content-Type', value: 'text/javascript'})
		code := if request.current_url().serialize() == 'https://private-worker.test/entry.js' {
			'globalThis.leaked=Reflect.ownKeys(globalThis).filter(key=>typeof key==="string"&&(key.startsWith("__ladybird")||key.startsWith("__vox")));onmessage=async()=>postMessage((await import("./late.js")).answer);'
		} else { 'export const answer=42;' }
		response.set_body_bytes(code.bytes())
		return response
	}}
	mut agent := WorkerAgentRuntime.create(url, html.WorkerOptions{type_: .module_},
		html.SerializedEnvironmentSettingsObject{creation_url: url, api_base_url: url, origin: url.origin(),
			policy_container: html.SerializedPolicyContainer{referrer_policy: .strict_origin_when_cross_origin},
			global: html.SerializedWindow{associated_document: html.SerializedDocument{url: url, relevant_settings_object_is_secure_context: true}}
		}, 12, transport)!
	defer { agent.close() }
	agent.load_entry()!
	assert agent.runtime.evaluate_host('leaked.length')! == '0', agent.runtime.evaluate_host('JSON.stringify(leaked)')!
	host := agent.runtime.module_host_?
	agent.runtime.evaluate_host('globalThis.${host.helper_name}=()=>{throw Error("author import helper")};')!
	mut sender := Runtime.create()
	defer { sender.close() }
	transfer := ArrayBufferTransferBridge.create(sender)!
	agent.queue_message(encode_worker_message(transfer.serialize(sender.evaluate_host_value('1')!, [])!)!)!
	deadline := time.sys_mono_now() + 5 * time.second
	mut output := [][]u8{}
	for output.len == 0 && time.sys_mono_now() < deadline {
		agent.process()
		platform.pump_native_events(0.001)
		output = agent.take_outgoing()
	}
	assert output.len == 1
	actual := transfer.deserialize(decode_worker_message(output[0])!)!
	sender.define_value_host_function('__privateHelperReply', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert sender.evaluate_host('__privateHelperReply()')! == '42'
}
