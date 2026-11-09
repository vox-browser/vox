module browserjs

import dom
import html
import loader
import net
import os
import platform
import time

// The fresh child uses this exact test executable and its native worker role.
fn test_shared_worker_process_entry() {
	if code := run_worker_process_role(os.args) { exit(code) }
}

fn serve_shared_worker_entry(mut listener net.TcpListener) {
	mut socket := listener.accept() or { return }
	defer { socket.close() or {} }
	mut request := []u8{len: 8192}
	length := socket.read(mut request) or { return }
	assert request[..length].bytestr().starts_with('GET /entry.js HTTP/1.1\r\n')
	script := r'
let count=0;
onconnect=event=>{const current=++count,port=event.ports[0];port.onmessage=event=>port.postMessage({count:current,echo:event.data,scope:self instanceof SharedWorkerGlobalScope});port.postMessage({count:current,name});};
'
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: ${script.len}\r\nConnection: close\r\n\r\n${script}') or {}
}

fn pump_shared_workers(hosts []&SharedWorkerHost, runtimes []&Runtime, conditions []string) ! {
	deadline := time.now().add(15 * time.second)
	for {
		for actual in hosts {
			mut host := unsafe { &SharedWorkerHost(actual) }
			host.poll()
			mut owner := host.settings.responsible_event_loop()
			mut queue := owner.task_queue()
			for _ in 0 .. 1000 {
				task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .posted_message }) or { break }
				task.execute()
			}
			owner.perform_a_microtask_checkpoint()
		}
		mut done := true
		for index, actual in runtimes {
			mut runtime := unsafe { &Runtime(actual) }
			if runtime.evaluate_host(conditions[index])! != 'true' { done = false }
		}
		if done { return }
		if time.now() > deadline { return error('SharedWorker process/port deadline') }
		platform.pump_native_events(0.002)
	}
}

fn test_shared_worker_reuses_one_process_across_connections_and_window_owners() {
	if !loader.is_initialized() { loader.initialize() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_shared_worker_entry(mut listener)
	url := dom.URL{value: 'http://${listener.addr()!}/page'}
	mut first_document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut second_document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut first := Runtime.create()
	mut second := Runtime.create()
	defer { first.close(); second.close(); first_document.finalize(); second_document.finalize() }
	first_settings := unsafe { &html.EnvironmentSettingsObject(first_document.relevant_settings_object()) }
	second_settings := unsafe { &html.EnvironmentSettingsObject(second_document.relevant_settings_object()) }
	mut first_host := SharedWorkerHost.create(first_settings, os.executable())!
	mut second_host := SharedWorkerHost.create(second_settings, os.executable())!
	first_host.install(mut first)!
	second_host.install(mut second)!
	assert first.evaluate_host(r'
globalThis.messages=[];globalThis.errors=[];
class Derived extends SharedWorker{};globalThis.a=new Derived("/entry.js","reused"),b=new SharedWorker("/entry.js",{name:"reused"});
a.onerror=event=>errors.push(event.type);b.onerror=event=>errors.push(event.type);
a.port.onmessage=event=>messages.push(event.data);b.port.onmessage=event=>messages.push(event.data);
a instanceof Derived&&a instanceof SharedWorker&&a instanceof EventTarget&&a.port===a.port&&a.port instanceof MessagePort&&Object.prototype.toString.call(a)==="[object SharedWorker]"&&a.port!==b.port
')! == 'true'
	second.evaluate_host(r'globalThis.messages=[];globalThis.c=new SharedWorker("/entry.js","reused");c.port.onmessage=event=>messages.push(event.data);')!
	pump_shared_workers([first_host, second_host], [first, second], ['messages.length===2||errors.length>0', 'messages.length===1'])!
	assert first.evaluate_host('errors.length===0&&messages[0].count===1&&messages[1].count===2&&messages.every(value=>value.name==="reused")')! == 'true'
	assert second.evaluate_host('messages[0].count===3&&messages[0].name==="reused"')! == 'true'
	connections := first_host.connections.values()
	assert connections.len == 2 && connections[0].remote.owners.len == 3
	assert voidptr(connections[0].remote) == voidptr(second_host.connections.values()[0].remote)
	first_host.close()
	second.evaluate_host('c.port.postMessage("still connected")')!
	pump_shared_workers([second_host], [second], ['messages.length===2'])!
	assert second.evaluate_host('messages[1].count===3&&messages[1].echo==="still connected"&&messages[1].scope')! == 'true'
	second_host.close()
	assert remote_shared_workers_.len == 0
	server.wait()
}

fn test_shared_worker_constructor_conversions_receivers_and_async_failure() {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://shared-host.test/page'}
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut host := SharedWorkerHost.create(settings, '/nonexistent-shared-worker-test')!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
globalThis.order=[];globalThis.failures=[];
globalThis.worker=new SharedWorker({toString(){order.push("url");return "/entry.js"}},{get credentials(){order.push("credentials");return "same-origin"},get extendedLifetime(){order.push("extendedLifetime");return false},get name(){order.push("name");return "name"},get type(){order.push("type");return "classic"}});
worker.onerror=event=>failures.push(event.target===worker&&event.isTrusted&&event.cancelable);
let invalid=0;const get=Object.getOwnPropertyDescriptor(SharedWorker.prototype,"port").get;
for(const call of [()=>SharedWorker("url"),()=>new SharedWorker(),()=>new SharedWorker(Symbol()),()=>new SharedWorker("url",{type:"bad"}),()=>new SharedWorker("url",{credentials:"bad"}),()=>get.call({})]){try{call()}catch(error){if(error instanceof TypeError)invalid++}}
order.join(",")==="url,credentials,extendedLifetime,name,type"&&invalid===6&&failures.length===0&&SharedWorker.length===1&&get.length===0
')! == 'true'
	mut queue := settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .posted_message }) or { break }
		task.execute()
	}
	assert runtime.evaluate_host('failures.join()')! == 'true'
}

fn test_upstream_shared_worker_over_native_process_and_ports() {
	base := os.getenv('VOX_SHARED_WPT_BASE')
	if base == '' { return }
	root := os.getenv('VOX_PINNED_WPT_ROOT')
	name := os.getenv('VOX_SHARED_WPT_CASE')
	assert root != '' && name.ends_with('.any.sharedworker')
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: base + '/' + name + '.html'}
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut host := SharedWorkerHost.create(settings, os.executable())!
	host.install(mut runtime)!
	mut params := URLSearchParamsHost.create_for_settings(settings)!
	params.install(mut runtime)!
	mut urls := URLHost.create_for_settings(settings)!
	urls.install(mut runtime)!
	runtime.evaluate_host('globalThis.self=globalThis;globalThis.location=new URL("'+url.serialize()+'");globalThis.nativeWptResult=null;')!
	runtime.evaluate_host(os.read_file(os.join_path(root, 'resources/testharness.js'))!)!
	runtime.evaluate_host('setup({output:false,explicit_done:true});add_completion_callback((tests,status)=>{globalThis.nativeWptResult={harness:status.status,harness_message:status.message,tests:tests.map(t=>({name:t.name,status:t.status,message:t.message}))}});')!
	entry := name.all_before('.sharedworker') + '.worker.js'
	runtime.evaluate_host('fetch_tests_from_worker(new SharedWorker("'+base+'/'+entry+'")).then(()=>done());')!
	pump_shared_workers([host], [runtime], ['nativeWptResult!==null'])!
	result := runtime.evaluate_host('JSON.stringify(nativeWptResult)')!
	os.write_file(os.getenv('VOX_SHARED_WPT_RESULT'), result)!
	println(result)
	assert runtime.evaluate_host('nativeWptResult.harness===0&&nativeWptResult.tests.length>0&&nativeWptResult.tests.every(t=>t.status===0)')! == 'true', result
}
