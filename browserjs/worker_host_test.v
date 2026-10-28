module browserjs

import dom
import html
import loader
import platform

fn worker_host_fixture() !(&Runtime, &WorkerHost, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://worker-parent.test/maps/current'}
	document := html.parse_navigation_document('<!doctype html><base href="/assets/">', url, url.origin(), none)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := WorkerHost.create(settings, '/nonexistent-vox-worker-executable')!
	host.install(mut runtime)!
	return runtime, host, document
}

fn worker_host_test_tasks(settings &html.EnvironmentSettingsObject) {
	mut queue := settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .posted_message }) or { break }
		task.execute()
	}
}

fn worker_host_test_remote(runtime &Runtime, host &WorkerHost, expression string) !&RemoteWorker {
	value := runtime.evaluate_host_value(expression)!
	return host.workers[value] or { return error('Missing actual remote Worker') }
}

fn test_worker_parent_constructor_preserves_conversion_order_url_resolution_and_actual_event_target() {
	mut runtime, mut host, mut document := worker_host_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.order=[];globalThis.received=[];
 class MapWorker extends Worker{}
 globalThis.worker=new MapWorker({toString(){order.push("url");return "../entry.js"}},{
  get credentials(){order.push("credentials");return "include"},
  get name(){order.push("name");return "Санкт-Петербург 😀"},
  get type(){order.push("type");return "classic"}
 });
 worker.onerror=function(event){received.push({event,receiver:this,current:event.currentTarget})};
 worker instanceof MapWorker&&worker instanceof Worker&&worker instanceof EventTarget&&Object.prototype.toString.call(worker)==="[object Worker]"&&order.join()==="url,credentials,name,type"&&received.length===0&&Worker.length===1&&Worker.prototype.postMessage.length===1&&Worker.prototype.terminate.length===0;
 ')! == 'true'
	remote := worker_host_test_remote(runtime, host, 'worker')!
	assert remote.worker.script_url.serialize() == 'https://worker-parent.test/entry.js'
	assert remote.worker.options.name == 'Санкт-Петербург 😀'
	assert remote.worker.options.credentials == .include
	assert remote.worker.scope() == none
	assert remote.worker.outside_message_port() == none
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('worker')!)!) == voidptr(remote.worker.this_event_target())
	assert remote.process == none
	worker_host_test_tasks(host.settings)
	assert runtime.evaluate_host('received.length===1&&received[0].event.type==="error"&&received[0].event.isTrusted&&received[0].event.cancelable&&received[0].event.target===worker&&received[0].receiver===worker&&received[0].current===worker&&received[0].event.currentTarget===null')! == 'true'
	host.poll()
	assert !host.timer.is_active()
}

fn test_worker_parent_rejects_invalid_arguments_and_foreign_receivers_before_starting_a_process() {
	mut runtime, host, mut document := worker_host_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 let errors=0;
 for(const construct of [()=>Worker("x"),()=>new Worker(),()=>new Worker(Symbol()),()=>new Worker("x",3),()=>new Worker("x",{type:"bad"}),()=>new Worker("x",{credentials:"bad"}),()=>Worker.prototype.postMessage.call({},1),()=>Worker.prototype.terminate.call({}),()=>Object.getOwnPropertyDescriptor(Worker.prototype,"onmessage").get.call({})]){try{construct()}catch(e){if(e instanceof TypeError)errors++}}
 let syntax=false;try{new Worker("http://[")}catch(e){syntax=e instanceof DOMException&&e.name==="SyntaxError"}
 errors===9&&syntax;
 ')! == 'true'
	assert host.workers.len == 0
}

fn test_worker_parent_delivers_clones_as_trusted_messages_in_the_receiving_realm() {
	mut runtime, mut host, mut document := worker_host_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host('globalThis.worker=new Worker("map.js");globalThis.messages=[];worker.onmessage=function(event){messages.push({event,receiver:this})}')!
	remote := worker_host_test_remote(runtime, host, 'worker')!
	value := runtime.evaluate_host_value('globalThis.original=(()=>{const buffer=new ArrayBuffer(4),view=new Uint8Array(buffer);view[0]=42;const value={buffer,view,label:"Санкт-Петербург 😀"};value.self=value;return value})()')!
	buffer := runtime.evaluate_host_value('original.buffer')!
	host.queue_message(remote, encode_worker_message(host.transfer.serialize(value, [buffer])!)!)!
	assert runtime.evaluate_host('messages.length===0&&original.buffer.byteLength===0')! == 'true'
	worker_host_test_tasks(host.settings)
	assert runtime.evaluate_host(r'
 const event=messages[0].event,value=event.data;
 messages.length===1&&messages[0].receiver===worker&&event instanceof MessageEvent&&event.isTrusted&&event.target===worker&&event.currentTarget===null&&event.source===null&&event.origin===""&&event.lastEventId===""&&event.ports.length===0&&Object.isFrozen(event.ports)&&value!==original&&value.self===value&&value.buffer instanceof ArrayBuffer&&value.view instanceof Uint8Array&&value.view.buffer===value.buffer&&value.view[0]===42&&value.label==="Санкт-Петербург 😀";
 ')! == 'true'
	if _ := host.queue_message(remote, [u8(255)]) { assert false }
}

fn test_worker_parent_termination_and_runtime_close_discard_already_scheduled_deliveries() {
	mut runtime, mut host, mut document := worker_host_fixture()!
	defer { document.finalize() }
	runtime.evaluate_host('globalThis.worker=new Worker("map.js");globalThis.called=0;worker.onmessage=worker.onerror=()=>called++')!
	remote := worker_host_test_remote(runtime, host, 'worker')!
	bytes := encode_worker_message(host.transfer.serialize(runtime.evaluate_host_value('42')!, [])!)!
	host.queue_message(remote, bytes)!
	runtime.evaluate_host('worker.terminate();worker.terminate()')!
	// A closed outside port still serializes before discarding the message.
	assert runtime.evaluate_host(r'
 let reads=0;const buffer=new ArrayBuffer(4);
 worker.postMessage({get value(){reads++;return 42},buffer},[buffer]);
 let rejected=false;try{worker.postMessage(()=>{})}catch(e){rejected=e instanceof DOMException&&e.name==="DataCloneError"}
 reads===1&&buffer.byteLength===0&&rejected;
 ')! == 'true'
	worker_host_test_tasks(host.settings)
	assert runtime.evaluate_host('called===0')! == 'true'
	assert remote.worker.terminated_
	runtime.evaluate_host('globalThis.other=new Worker("other.js");other.onmessage=other.onerror=()=>{throw Error("closed realm callback")}')!
	other := worker_host_test_remote(runtime, host, 'other')!
	host.queue_message(other, bytes)!
	runtime.close()
	worker_host_test_tasks(host.settings)
	assert host.closed && host.workers.len == 0 && !host.timer.is_active()
	assert other.worker.terminated_
	assert voidptr(runtime) !in worker_host_bindings_
}

fn test_worker_parent_owns_constructor_and_delivery_data_after_scratch_arenas_are_poisoned() {
	mut runtime, mut host, mut document := worker_host_fixture()!
	defer { runtime.close(); document.finalize() }
	mut caller := platform.begin_thread_scratch('worker parent caller')
	runtime.evaluate_host('globalThis.worker=new Worker("map.js",{name:"Санкт-Петербург 😀"});globalThis.saved=null;worker.onmessage=event=>saved=event.data')!
	caller.finish()
	remote := worker_host_test_remote(runtime, host, 'worker')!
	mut delivery := platform.begin_thread_scratch('worker parent delivery')
	host.queue_message(remote, encode_worker_message(host.transfer.serialize(runtime.evaluate_host_value('({text:"persistent",values:[1,2,3]})')!, [])!)!)!
	delivery.finish()
	worker_host_test_tasks(host.settings)
	assert remote.worker.options.name == 'Санкт-Петербург 😀'
	assert remote.worker.script_url.serialize() == 'https://worker-parent.test/assets/map.js'
	assert runtime.evaluate_host('saved.text==="persistent"&&saved.values.join()==="1,2,3"')! == 'true'
}

fn test_worker_parent_enforces_runtime_ownership_and_discarded_environment_cleanup() {
	mut runtime, mut host, mut document := worker_host_fixture()!
	defer { runtime.close(); document.finalize() }
	host.install(mut runtime)!
	mut other := Runtime.create()
	defer { other.close() }
	if _ := host.install(mut other) { assert false }
	mut competitor := WorkerHost.create(host.settings, '/nonexistent-vox-worker-executable')!
	if _ := competitor.install(mut runtime) { assert false }
	for executable in ['', 'vox\x00worker'] { if _ := WorkerHost.create(host.settings, executable) { assert false } }
	runtime.evaluate_host('globalThis.worker=new Worker("map.js");worker.onerror=()=>{throw Error("discarded environment callback")}')!
	remote := worker_host_test_remote(runtime, host, 'worker')!
	mut settings := unsafe { &html.EnvironmentSettingsObject(host.settings) }
	settings.set_discarded(true)
	host.poll()
	worker_host_test_tasks(settings)
	assert host.closed && remote.worker.terminated_
}
