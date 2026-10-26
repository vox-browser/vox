module browserjs

import dom
import html
import loader

fn worker_message_event_fixture() !(&Runtime, &html.DedicatedWorkerGlobalScope, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://worker-message.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	outside := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(dom.URL{ value: 'https://worker-message.test/agent.js' }, html.WorkerOptions{}, realm)
	settings := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm, outside.serialize(), 12).settings
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings)!
	runtime.install_message_event_binding()!
	return runtime, scope, document
}

fn test_worker_message_event_constructor_uses_its_realm_without_window_messaging() {
	mut runtime, _, mut document := worker_message_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const payload={text:"worker"};class Derived extends MessageEvent{};
 const event=new Derived("custom",{data:payload,bubbles:true,cancelable:true});
 const initial=event instanceof Derived&&event instanceof MessageEvent&&event instanceof Event&&event.data===payload&&event.source===null&&event.origin===""&&event.lastEventId===""&&event.bubbles&&event.cancelable&&!event.isTrusted&&Object.isFrozen(event.ports)&&event.ports===event.ports;
 event.initMessageEvent("next",false,false,17,"origin","id",null,[]);
 let errors=0;for(const make of [()=>MessageEvent("x"),()=>new MessageEvent(),()=>new MessageEvent("x",{source:globalThis}),()=>new MessageEvent("x",{ports:[{}]})]){try{make()}catch(e){if(e instanceof TypeError)errors++}}
 initial&&event.type==="next"&&event.data===17&&event.origin==="origin"&&event.lastEventId==="id"&&errors===4&&typeof window==="undefined"&&typeof postMessage==="undefined";
 ')! == 'true'
	// Installing another common binding must preserve the worker sender supplied
	// by its embedding rather than replacing it with Window overloads.
	runtime.evaluate_host('globalThis.postMessage=function workerSender(){}')!
	runtime.install_message_event_binding()!
	assert runtime.evaluate_host('postMessage.name==="workerSender"')! == 'true'
}

fn test_worker_message_event_wraps_native_cloned_data_and_trusted_dispatch() {
	mut runtime, scope, mut document := worker_message_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.bind_event_target(runtime.evaluate_host_value('globalThis')!, scope.this_impl())!
	runtime.evaluate_host(r'
 globalThis.original={text:"before",bytes:new Uint8Array([0,255,128]),map:new Map([["key",7n]])};original.self=original;
 globalThis.seen=null;EventTarget.prototype.addEventListener.call(globalThis,"message",function(event){seen={event,receiver:this,target:event.target,current:event.currentTarget};});
 ')!
	bridge := StructuredCloneBridge.create(runtime)!
	serialized := bridge.serialize(runtime.evaluate_host_value('original')!, false)!
	mut event := html.MessageEvent.create('message', html.MessageEventInit{
		data: html.structured_deserialize(serialized)!
	})
	event.set_is_trusted(true)
	runtime.evaluate_host('original.text="after";original.bytes[0]=9')!
	scope.dispatch_event(unsafe { &dom.Event(event) })
	assert runtime.evaluate_host(r'
 const event=seen.event,data=event.data;
 event instanceof MessageEvent&&event instanceof Event&&event.isTrusted&&seen.receiver===globalThis&&seen.target===globalThis&&seen.current===globalThis&&event.currentTarget===null&&data===event.data&&data!==original&&data.text==="before"&&data.self===data&&data.bytes instanceof Uint8Array&&Array.from(data.bytes).join(",")==="0,255,128"&&data.map.get("key")===7n&&event.origin===""&&event.source===null&&event.ports.length===0&&Object.isFrozen(event.ports);
 ')! == 'true'
}
