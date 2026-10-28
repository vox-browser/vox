module browserjs

import dom
import html
import platform

fn worker_global_fixture() !(&Runtime, &WorkerGlobalHost) {
	url := dom.URL{value: 'https://worker-global.test/agents/map.js?lang=ru'}
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{name: 'map worker'}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{
			creation_url: url
			api_base_url: url
			origin: url.origin()
			global: html.SerializedWorkerGlobalScope{relevant_settings_object_is_secure_context: true}
		}, 12)
	mut runtime := Runtime.create_for_worker()
	mut host := WorkerGlobalHost.create(environment)!
	host.install(mut runtime)!
	return runtime, host
}

fn drain_worker_global_messages(loop &html.EventLoop) {
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .posted_message }) or { break }
		task.execute()
	}
}

fn test_worker_global_uses_actual_global_identity_prototypes_handlers_and_replaceable_attributes() {
	mut runtime, mut host := worker_global_fixture()!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 self===globalThis&&self instanceof DedicatedWorkerGlobalScope&&self instanceof WorkerGlobalScope&&self instanceof EventTarget&&Object.getPrototypeOf(globalThis)===DedicatedWorkerGlobalScope.prototype&&Object.getPrototypeOf(DedicatedWorkerGlobalScope.prototype)===WorkerGlobalScope.prototype&&Object.getPrototypeOf(WorkerGlobalScope.prototype)===EventTarget.prototype&&Object.prototype.toString.call(self)==="[object DedicatedWorkerGlobalScope]"&&name==="map worker"&&origin==="https://worker-global.test"&&isSecureContext&&location.pathname==="/agents/map.js"&&typeof window==="undefined"&&typeof document==="undefined";
 ')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.hits=[];onmessage=function(event){hits.push(this===self&&event.currentTarget===self&&event.target===self)};
 const listener=()=>hits.push("listener");addEventListener("message",listener);dispatchEvent(new MessageEvent("message"));removeEventListener("message",listener);dispatchEvent(new MessageEvent("message"));
 let rejected=0;for(const call of [()=>new WorkerGlobalScope(),()=>WorkerGlobalScope(),()=>new DedicatedWorkerGlobalScope(),()=>DedicatedWorkerGlobalScope(),()=>postMessage.call({},1),()=>close.call({}),()=>Object.getOwnPropertyDescriptor(WorkerGlobalScope.prototype,"self").get.call({})]){try{call()}catch(error){if(error instanceof TypeError)rejected++}}
 const descriptor=Object.getOwnPropertyDescriptor(DedicatedWorkerGlobalScope.prototype,"postMessage");
 rejected===7&&hits.join() === "true,listener,true"&&onmessage instanceof Function&&onmessageerror===null&&onerror===null&&postMessage.name==="postMessage"&&postMessage.length===1&&close.name==="close"&&close.length===0&&addEventListener.length===2&&dispatchEvent.length===1&&descriptor.enumerable&&descriptor.configurable&&descriptor.writable;
 ')! == 'true'
	runtime.evaluate_host('globalThis.replacement={};name=replacement;origin=replacement;onmessage=17')!
	assert runtime.evaluate_host('name===replacement&&origin===replacement&&onmessage===null&&self===globalThis')! == 'true'
	assert host.scope.name() == 'map worker'
	assert host.environment.settings.origin().serialize() == 'https://worker-global.test'
	host.install(mut runtime)!
}

fn test_worker_global_post_message_converts_overloads_before_clone_and_detaches_in_transfer_order() {
	mut runtime, mut host := worker_global_fixture()!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 globalThis.first=new ArrayBuffer(3);new Uint8Array(first).set([0,128,255]);globalThis.second=new ArrayBuffer(1);
 globalThis.value={first,view:new Uint8Array(first,1)};value.self=value;
 postMessage(value,[first]);postMessage({second},{transfer:new Set([second])});postMessage("plain");
 first.detached&&second.detached;
 ')! == 'true'
	messages := host.take_outgoing()
	assert messages.len == 3
	assert host.take_outgoing().len == 0
	assert decode_worker_message(messages[0])!.buffers[0].bytes == [u8(0),128,255]
	assert decode_worker_message(messages[1])!.buffers[0].bytes == [u8(0)]
	assert decode_worker_message(messages[2])!.buffers.len == 0
	assert runtime.evaluate_host(r'
 globalThis.order=[];globalThis.duplicate=new ArrayBuffer(1);globalThis.reason={original:true};let errors=0;
 for(const call of [()=>postMessage(),()=>postMessage(1,3),()=>postMessage(1,{transfer:null}),()=>postMessage(1,[1])]){try{call()}catch(error){if(error instanceof TypeError)errors++}}
 const options={get [Symbol.iterator](){order.push("overload");return undefined},get transfer(){order.push("transfer");return {get [Symbol.iterator](){order.push("iterator");return function*(){order.push("entry");yield duplicate}}}}};
 postMessage({get value(){order.push("graph");return 7}},options);
 let cloneError=false;try{postMessage({get value(){throw reason}},[new ArrayBuffer(1)])}catch(error){cloneError=error===reason}
 globalThis.other=new ArrayBuffer(1);let duplicateError=false;try{postMessage({get value(){throw reason}},[other,other])}catch(error){duplicateError=error instanceof DOMException&&error.name==="DataCloneError"}
 errors===4&&order.join() === "overload,transfer,iterator,entry,graph"&&duplicate.detached&&cloneError&&duplicateError&&!other.detached;
 ')! == 'true'
	assert host.take_outgoing().len == 1
	assert runtime.evaluate_host(r'
 const push=Array.prototype.push,poisoned=new ArrayBuffer(1);
 try{Array.prototype.push=()=>{throw Error("author push")};postMessage({poisoned},[poisoned])}
 finally{Array.prototype.push=push}
 poisoned.detached;
 ')! == 'true'
	assert host.take_outgoing().len == 1
}

fn test_worker_global_wire_delivery_uses_receiver_realm_trusted_events_and_its_own_task_queue() {
	mut sender, mut send := worker_global_fixture()!
	mut receiver, mut receive := worker_global_fixture()!
	defer { sender.close(); receiver.close() }
	sender.evaluate_host('globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);globalThis.value={buffer,view:new Uint8Array(buffer,1),map:new Map([["key",7n]])};value.self=value;postMessage(value,[buffer]);')!
	receiver.evaluate_host('globalThis.seen=[];onmessage=function(event){seen.push({event,receiver:this,current:event.currentTarget})};')!
	for bytes in send.take_outgoing() { receive.queue_message(bytes)! }
	assert receiver.evaluate_host('seen.length===0')! == 'true'
	drain_worker_global_messages(html.main_thread_event_loop())
	assert receiver.evaluate_host('seen.length===0')! == 'true'
	drain_worker_global_messages(receive.scope.event_loop)
	assert receiver.evaluate_host(r'
 const item=seen[0],event=item.event,value=event.data;
 seen.length===1&&item.receiver===self&&item.current===self&&event.target===self&&event.currentTarget===null&&event instanceof MessageEvent&&event instanceof Event&&event.isTrusted&&value===event.data&&value.self===value&&value.buffer instanceof ArrayBuffer&&value.view instanceof Uint8Array&&value.view.buffer===value.buffer&&Array.from(value.view).join() === "128,255"&&value.map instanceof Map&&value.map.get("key")===7n&&event.source===null&&event.origin===""&&event.lastEventId===""&&Object.isFrozen(event.ports)&&event.ports.length===0;
 ')! == 'true'
	assert sender.evaluate_host('buffer.detached')! == 'true'
}

fn test_worker_global_invalid_graph_fires_messageerror_and_close_discards_queued_delivery() {
	mut runtime, mut host := worker_global_fixture()!
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.errors=[];globalThis.messages=[];onmessageerror=function(event){errors.push(event)};onmessage=event=>messages.push(event.data);')!
	host.queue_message(encode_worker_message(NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: [u8(255)]}})!)!
	drain_worker_global_messages(host.scope.event_loop)
	assert runtime.evaluate_host('errors.length===1&&errors[0] instanceof MessageEvent&&errors[0].type==="messageerror"&&errors[0].isTrusted&&errors[0].target===self&&errors[0].data===null&&messages.length===0')! == 'true'
	runtime.evaluate_host('postMessage("before close")')!
	for bytes in host.take_outgoing() { host.queue_message(bytes)! }
	runtime.evaluate_host('close();postMessage("after close")')!
	assert host.scope.is_closing()
	drain_worker_global_messages(host.scope.event_loop)
	assert runtime.evaluate_host('messages.length===0')! == 'true'
	assert host.take_outgoing().len == 1
	host.queue_message([u8(255)])! // Closed scopes ignore incoming messages.
}

fn test_worker_global_rejects_multiple_owners_and_shutdown_releases_queued_delivery() {
	mut runtime, mut host := worker_global_fixture()!
	mut duplicate := WorkerGlobalHost.create(host.environment)!
	duplicate.install(mut runtime) or {
		assert err.msg().contains('already belongs')
		mut second := Runtime.create()
		defer { second.close() }
		host.install(mut second) or {
			assert err.msg().contains('another runtime')
			runtime.evaluate_host('postMessage("queued");onmessage=()=>{throw new Error("closed realm callback")};')!
			for bytes in host.take_outgoing() { host.queue_message(bytes)! }
			runtime.close()
			assert host.closed
			assert host.scope.is_closing()
			assert voidptr(runtime) !in worker_global_bindings_
			assert host.take_outgoing().len == 0
			drain_worker_global_messages(host.scope.event_loop)
			return
		}
		runtime.close()
		assert false, 'one dedicated worker host acquired two runtimes'
		return
	}
	runtime.close()
	assert false, 'duplicate dedicated worker global binding installed'
}

fn test_worker_global_messages_and_events_survive_caller_and_delivery_scratch_resets() {
	mut caller := platform.begin_thread_scratch('worker global caller')
	// Source models themselves belong to the agent lifetime, as in worker startup.
	persistent := platform.enter_persistent()
	mut runtime, mut host := worker_global_fixture()!
	platform.leave_persistent(persistent)
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.saved=null;onmessage=event=>saved=event;postMessage({text:"Санкт-Петербург 😀".repeat(64),bytes:new Uint8Array([0,128,255])});')!
	for bytes in host.take_outgoing() { host.queue_message(bytes)! }
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker global delivery')
	drain_worker_global_messages(host.scope.event_loop)
	delivery.finish()
	assert runtime.evaluate_host('saved.target===self&&saved.currentTarget===null&&saved.data.text==="Санкт-Петербург 😀".repeat(64)&&saved.data.bytes instanceof Uint8Array&&Array.from(saved.data.bytes).join() === "0,128,255"')! == 'true'
}
