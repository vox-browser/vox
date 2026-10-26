module browserjs

import dom
import html
import loader
import platform

fn worker_channel_binding_fixture() !(&Runtime, &html.DedicatedWorkerGlobalScope, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://worker-channel.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	outside := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(dom.URL{ value: 'https://worker-channel.test/agent.js' }, html.WorkerOptions{}, realm)
	settings := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm, outside.serialize(), 12).settings
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings)!
	runtime.install_message_channel_binding()!
	return runtime, scope, document
}

fn drain_worker_channel_tasks(loop &html.EventLoop) {
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .posted_message
		}) or { break }
		task.execute()
	}
}

fn test_worker_message_channel_clones_values_and_dispatches_on_the_worker_loop() {
	mut runtime, scope, mut document := worker_channel_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.received=[];
 globalThis.original={text:"before",map:new Map([["key",7n]]),bytes:new Uint8Array([0,255,128])};original.self=original;
 channel.port1.onmessage=function(event){received.push({event,receiver:this,current:event.currentTarget});};
 channel.port2.postMessage(original);original.text="after";original.bytes[0]=9;
 channel.port2.postMessage("second");
 received.length===0&&typeof window==="undefined"&&typeof postMessage==="undefined";
 ')! == 'true'
	drain_worker_channel_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('received.length===0')! == 'true'
	drain_worker_channel_tasks(scope.event_loop)
	assert runtime.evaluate_host(r'
 const item=received[0],event=item.event,data=event.data;
 received.length===2&&received[1].event.data==="second"&&event instanceof MessageEvent&&event instanceof Event&&event.isTrusted&&event.target===channel.port1&&item.receiver===channel.port1&&item.current===channel.port1&&event.currentTarget===null&&event.source===null&&event.origin===""&&data===event.data&&data!==original&&data.self===data&&data.text==="before"&&data.map.get("key")===7n&&Array.from(data.bytes).join(",")==="0,255,128"&&data.bytes!==original.bytes&&Object.isFrozen(event.ports)&&event.ports.length===0;
 ')! == 'true'
}

fn test_worker_message_channel_start_close_and_runtime_shutdown_keep_queued_callbacks_safe() {
	mut runtime, scope, mut document := worker_channel_binding_fixture()!
	defer { document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.received=[];
 channel.port1.addEventListener("message",event=>received.push(event.data));
 channel.port2.postMessage("waiting");true;
 ')! == 'true'
	drain_worker_channel_tasks(scope.event_loop)
	assert runtime.evaluate_host('received.length===0;')! == 'true'
	runtime.evaluate_host('channel.port1.start();channel.port1.start();')!
	drain_worker_channel_tasks(scope.event_loop)
	assert runtime.evaluate_host('received.join()==="waiting"')! == 'true'
	runtime.evaluate_host('channel.port2.postMessage("closed");channel.port1.close();')!
	drain_worker_channel_tasks(scope.event_loop)
	assert runtime.evaluate_host('received.join()==="waiting"')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.pending=new MessageChannel();pending.port1.onmessage=()=>{throw new Error("closed worker realm callback")};pending.port2.postMessage(2);
 let rejected=false;try{pending.port2.postMessage(0,[pending.port1])}catch(e){rejected=e instanceof DOMException&&e.name==="DataCloneError"}rejected;
 ')! == 'true'
	binding := message_channel_bindings_[voidptr(runtime)] or { panic('missing worker channels') }
	ports := binding.ports.values()
	runtime.close()
	for port in ports {
		assert port.is_detached()
	}
	drain_worker_channel_tasks(scope.event_loop)
}

fn test_worker_message_channel_messages_and_wrappers_survive_scratch_resets() {
	mut runtime, scope, mut document := worker_channel_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut caller := platform.begin_thread_scratch('worker channel caller')
	runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.saved=null;
 channel.port1.onmessage=event=>saved=event;
 channel.port2.postMessage({text:"Санкт-Петербург 😀".repeat(64),nested:{value:42}});
 ')!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker channel delivery')
	drain_worker_channel_tasks(scope.event_loop)
	delivery.finish()
	assert runtime.evaluate_host('saved.target===channel.port1&&saved.data.text==="Санкт-Петербург 😀".repeat(64)&&saved.data.nested.value===42')! == 'true'
}
