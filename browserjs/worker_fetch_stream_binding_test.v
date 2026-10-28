module browserjs

import dom
import fetch
import html
import net
import platform
import time

fn worker_fetch_settings(url dom.URL) &html.EnvironmentSettingsObject {
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
	return html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{
			creation_url: url
			api_base_url: url
			origin:       url.origin()
			global:       html.SerializedWorkerGlobalScope{ relevant_settings_object_is_secure_context: true }
		}, 12).settings
}

fn worker_fetch_runtime(mut host FetchHost) !&Runtime {
	mut runtime := Runtime.create()
	mut transform := TransformStreamHost.create_for_settings(host.settings)!
	transform.install(mut runtime)!
	mut strategies := QueuingStrategyHost.create_for_settings(host.settings)!
	strategies.install(mut runtime)!
	mut blobs := BlobHost.create_for_settings(host.settings)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut params := URLSearchParamsHost.create_for_settings(host.settings)!
	params.install(mut runtime)!
	host.install(mut runtime)!
	return runtime
}

fn worker_fetch_pending_transport() &fetch.FetchHost {
	return &fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('worker used blocking transport')
		}
		perform_async: fn (request &fetch.Request) &fetch.PendingResponse {
			mut actual := unsafe { &fetch.Request(request) }
			return fetch.PendingResponse.create(mut actual, none)
		}
	}
}

fn worker_fetch_until(host &FetchHost, runtime &Runtime, expression string) {
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := host.settings.responsible_event_loop()
	loop.spin_until(fn [runtime, expression, deadline] () bool {
		return runtime.evaluate_host(expression) or { 'false' } == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host(expression) or { 'false' } == 'true', expression
}

fn test_worker_streams_use_the_worker_realm_without_a_document() {
	settings := worker_fetch_settings(dom.URL{ value: 'https://worker-fetch.test/agents/main.js' })
	assert settings.responsible_document() == none
	mut host := FetchHost.create_for_settings(settings, worker_fetch_pending_transport())!
	mut runtime := worker_fetch_runtime(mut host)!
	defer { runtime.close() }
	owner := voidptr(settings)
	context := runtime.context
	runtime.define_value_host_function('__workerStreamOwner', fn [owner, context] (_ voidptr, _ []voidptr) !voidptr {
		settings := unsafe { &html.EnvironmentSettingsObject(owner) }
		assert voidptr(html.incumbent_settings_object()) == owner
		assert settings.realm().script_execution_depth >= 2
		assert settings.realm().callback_execution_depth >= 1
		return C.JSValueMakeBoolean(context, true)
	})!
	runtime.evaluate_host(r'
 globalThis.workerReads=[];globalThis.workerWritten=false;
 globalThis.workerTransform=new TransformStream({transform(chunk,controller){__workerStreamOwner();controller.enqueue(chunk+1)}},new CountQueuingStrategy({highWaterMark:2}),new CountQueuingStrategy({highWaterMark:0}));
 globalThis.workerWriter=workerTransform.writable.getWriter();globalThis.workerReader=workerTransform.readable.getReader();
 workerWriter.write(41).then(()=>workerWritten=true);
 ')!
	assert runtime.evaluate_host('!workerWritten&&typeof document==="undefined"&&typeof window==="undefined"')! == 'true'
	native := runtime.native_transform_stream(runtime.evaluate_host_value('workerTransform')!)!
	assert native.readable().realm().id == u64(voidptr(settings.realm()))
	assert native.writable().realm().id == u64(voidptr(settings.realm()))
	assert native.backpressure_change_promise_realm().id == u64(voidptr(settings.realm()))
	runtime.evaluate_host('workerReader.read().then(result=>workerReads.push(result.value));')!
	assert runtime.evaluate_host('workerWritten&&workerReads.join()==="42"')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.byteWorkerController=null;
 globalThis.byteWorkerStream=new ReadableStream({start(controller){byteWorkerController=controller}},new ByteLengthQueuingStrategy({highWaterMark:12}));
 byteWorkerController.enqueue(new Uint8Array(5));
 const first=new CountQueuingStrategy({highWaterMark:1}),second=new CountQueuingStrategy({highWaterMark:4});
 byteWorkerController.desiredSize===7&&first.size===second.size&&first.size()===1&&new ByteLengthQueuingStrategy({highWaterMark:1}).size(new Uint16Array(3))===6;
 ')! == 'true'
}

fn serve_worker_fetch(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut input := []u8{len: 4096}
	length := socket.read(mut input) or { panic(err) }
	assert input[..length].bytestr().starts_with('GET /agents/tile.bin HTTP/1.1\r\n')
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: 4\r\nX-Worker: native\r\nConnection: close\r\n\r\n') or { return }
	socket.write([u8(0), 128, 255, 65]) or {}
}

fn test_worker_native_fetch_resolves_relative_urls_and_clones_binary_response_streams() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_worker_fetch(mut listener)
	settings := worker_fetch_settings(dom.URL{ value: 'http://${listener.addr()!}/agents/main.js' })
	mut host := FetchHost.create_native_for_settings(settings)!
	mut runtime := worker_fetch_runtime(mut host)!
	defer { runtime.close() }
	runtime.evaluate_host(r'
 globalThis.workerFetchDone=false;globalThis.workerFetchError=null;
 fetch("./tile.bin").then(response=>{
  globalThis.workerResponse=response;globalThis.workerClone=response.clone();
  return Promise.all([response.bytes(),workerClone.arrayBuffer()]);
 }).then(values=>{globalThis.workerBytes=values[0];globalThis.workerBuffer=values[1];workerFetchDone=true},reason=>workerFetchError=reason);
 ')!
	worker_fetch_until(host, runtime, 'workerFetchDone||workerFetchError!==null')
	assert runtime.evaluate_host(r'
 workerFetchDone&&workerFetchError===null&&workerResponse instanceof Response&&workerResponse.body instanceof ReadableStream&&workerResponse.headers.get("x-worker")==="native"&&workerResponse.url.endsWith("/agents/tile.bin")&&workerResponse.bodyUsed&&workerClone.bodyUsed&&workerBytes instanceof Uint8Array&&workerBuffer instanceof ArrayBuffer&&Array.from(workerBytes).join(",")==="0,128,255,65"&&Array.from(new Uint8Array(workerBuffer)).join(",")==="0,128,255,65"&&typeof document==="undefined";
 ')! == 'true'
	stream := runtime.native_readable_stream(runtime.evaluate_host_value('workerResponse.body')!)!
	assert stream.realm().id == u64(voidptr(settings.realm()))
	// Body consumption can settle before the separate end-of-body fetch task.
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [host, deadline] () bool {
		return host.operations.len == 0 || time.sys_mono_now() >= deadline
	})
	assert host.operations.len == 0
	server.wait()
}

fn test_worker_fetch_abort_preserves_original_reason_and_runtime_close_stops_pending_operations() {
	settings := worker_fetch_settings(dom.URL{ value: 'https://worker-fetch.test/abort.js' })
	mut host := FetchHost.create_for_settings(settings, worker_fetch_pending_transport())!
	mut runtime := worker_fetch_runtime(mut host)!
	runtime.evaluate_host(r'
 globalThis.workerAbortCount=0;const controller=new AbortController(),reason={worker:true};
 fetch("/pending",{signal:controller.signal}).catch(error=>{if(error===reason)workerAbortCount++});
 controller.abort(reason);
 fetch("/already-aborted",{signal:controller.signal}).catch(error=>{if(error===reason)workerAbortCount++});
 ')!
	worker_fetch_until(host, runtime, 'workerAbortCount===2')
	assert host.operations.len == 0
	runtime.evaluate_host('fetch("/shutdown").then(()=>{throw new Error("closed worker fulfilled")},()=>{throw new Error("closed worker rejected")});')!
	assert host.operations.len == 1
	controller := host.operations[0].controller
	runtime.close()
	assert host.closed
	assert host.operations.len == 0
	assert controller.state() == .stopped
}

fn test_worker_abort_timeout_waits_for_its_owner_loop_and_stays_safe_after_runtime_close() {
	if !platform.native_timer_scheduling_available() { return }
	settings := worker_fetch_settings(dom.URL{ value: 'https://worker-fetch.test/timeout.js' })
	mut host := FetchHost.create_for_settings(settings, worker_fetch_pending_transport())!
	mut runtime := worker_fetch_runtime(mut host)!
	mut loop := settings.responsible_event_loop()
	pause := loop.pause()
	runtime.evaluate_host(r'
 globalThis.workerTimedOut=false;globalThis.workerTimeout=AbortSignal.timeout(5);
 workerTimeout.onabort=function(event){workerTimedOut=this===workerTimeout&&event.isTrusted&&event.target===workerTimeout&&workerTimeout.reason.name==="TimeoutError"};
 ')!
	scope := settings.window_or_worker_global_scope()!
	deadline := time.sys_mono_now() + 2 * time.second
	for scope.active_timer_count() > 0 && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	assert scope.active_timer_count() == 0
	assert runtime.evaluate_host('!workerTimeout.aborted&&!workerTimedOut')! == 'true'
	loop.unpause(pause)
	loop.schedule()
	worker_fetch_until(host, runtime, 'workerTimedOut')
	native := runtime.native_abort_signal(runtime.evaluate_host_value(r'
 globalThis.lateWorkerTimeout=AbortSignal.timeout(5);lateWorkerTimeout.onabort=()=>{throw new Error("released worker callback")};lateWorkerTimeout
 ')!)!
	runtime.close()
	end := time.sys_mono_now() + 2 * time.second
	for !native.aborted() && time.sys_mono_now() < end { platform.pump_native_events(0.01) }
	assert native.aborted()
}

fn test_worker_binding_install_rejects_a_different_settings_owner() {
	first := worker_fetch_settings(dom.URL{ value: 'https://worker-fetch.test/first.js' })
	second := worker_fetch_settings(dom.URL{ value: 'https://worker-fetch.test/second.js' })
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut readable := ReadableStreamHost.create_for_settings(first)!
	readable.install(mut runtime)!
	mut foreign := FetchHost.create_for_settings(second, worker_fetch_pending_transport())!
	foreign.install(mut runtime) or {
		assert err.msg().contains('different scripting environment')
		assert runtime.evaluate_host('typeof fetch==="undefined"&&typeof ReadableStream==="function"')! == 'true'
		return
	}
	assert false, 'worker fetch accepted a different settings owner'
}

fn test_worker_stream_and_response_values_survive_caller_and_delivery_scratch_resets() {
	settings := worker_fetch_settings(dom.URL{ value: 'https://worker-fetch.test/lifetime.js' })
	mut host := FetchHost.create_for_settings(settings, worker_fetch_pending_transport())!
	mut runtime := worker_fetch_runtime(mut host)!
	defer { runtime.close() }
	mut caller := platform.begin_thread_scratch('worker fetch caller')
	runtime.evaluate_host(r'
 globalThis.retainedWorkerTransform=new TransformStream();globalThis.retainedWorkerWriter=retainedWorkerTransform.writable.getWriter();globalThis.retainedWorkerReader=retainedWorkerTransform.readable.getReader();
 globalThis.retainedWorkerChunk={text:"Санкт-Петербург 😀".repeat(64)};globalThis.retainedWorkerWritten=false;globalThis.retainedWorkerRead=false;
 retainedWorkerWriter.write(retainedWorkerChunk).then(()=>retainedWorkerWritten=true);
 globalThis.retainedWorkerResponse=new Response(new Uint8Array([0,128,255]),{headers:{"X-Worker":"retained"}});globalThis.retainedWorkerCopy=retainedWorkerResponse.clone();
 ')!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker fetch delivery')
	runtime.evaluate_host(r'
 retainedWorkerReader.read().then(result=>retainedWorkerRead=result.value===retainedWorkerChunk);
 globalThis.retainedWorkerBodies=false;
 Promise.all([retainedWorkerResponse.bytes(),retainedWorkerCopy.bytes()]).then(values=>retainedWorkerBodies=values.every(value=>Array.from(value).join(",")==="0,128,255"));
 ')!
	delivery.finish()
	worker_fetch_until(host, runtime, 'retainedWorkerWritten&&retainedWorkerRead&&retainedWorkerBodies')
	assert runtime.evaluate_host('retainedWorkerChunk.text==="Санкт-Петербург 😀".repeat(64)&&retainedWorkerResponse.headers.get("x-worker")==="retained"')! == 'true'
}
