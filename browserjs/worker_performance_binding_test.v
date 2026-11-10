module browserjs

import dom
import fetch
import highresolutiontime
import html
import http
import platform
import usertiming

fn worker_performance_fixture(module_worker bool) !(&Runtime, &html.WorkerEnvironmentSettingsObject) {
	url := dom.URL{ value: 'https://worker-performance.test/agent.js' }
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{ creation_url: url, api_base_url: url, origin: url.origin(),
			global: html.SerializedWorkerGlobalScope{ relevant_settings_object_is_secure_context: true }
		}, highresolutiontime.unsafe_shared_current_time())
	mut runtime := if module_worker { Runtime.create_for_module_worker() } else { Runtime.create_for_worker() }
	mut global := WorkerGlobalHost.create(environment)!
	global.install(mut runtime)!
	runtime.install_performance_binding()!
	return runtime, environment
}

fn test_worker_performance_uses_its_own_clock_timeline_and_native_receiver() {
	for module_worker in [false, true] {
		mut runtime, environment := worker_performance_fixture(module_worker)!
		defer { runtime.close() }
		runtime.install_performance_binding()!
		mut scope := environment.settings.window_or_worker_global_scope()!
		mut performance := scope.performance()
		before := performance.now()
		now := runtime.evaluate_host('performance.now()')!.f64()
		after := performance.now()
		assert now >= before && now <= after
		assert runtime.evaluate_host('performance.timeOrigin')!.f64() == performance.time_origin()
		performance.mark('worker mark', usertiming.PerformanceMarkOptions{ start_time: 3 })!
		assert runtime.evaluate_host(r'
 let brands=0;for(const call of [()=>Performance.prototype.now.call({}),()=>new Performance()]){try{call()}catch(e){if(e instanceof TypeError)brands++}}
 const entries=performance.getEntries();
 brands===2&&performance instanceof Performance&&performance instanceof EventTarget&&Object.prototype.toString.call(performance)==="[object Performance]"&&entries.length===1&&entries[0].name==="worker mark"&&entries[0]===performance.getEntriesByName("worker mark")[0]&&performance.toJSON().timeOrigin===performance.timeOrigin&&!("timing" in performance)&&!("navigation" in performance)&&typeof document==="undefined"&&typeof VisibilityStateEntry==="undefined"&&!PerformanceObserver.supportedEntryTypes.includes("visibility-state");
 ')! == 'true'
	}
}

fn test_worker_performance_observers_use_the_worker_queue_and_survive_scratch_reset() {
	mut runtime, environment := worker_performance_fixture(true)!
	defer { runtime.close() }
	mut scope := environment.settings.window_or_worker_global_scope()!
	mut performance := scope.performance()
	performance.mark('buffered worker mark', usertiming.PerformanceMarkOptions{ start_time: 7 })!
	mut caller := platform.begin_thread_scratch('worker performance caller')
	runtime.evaluate_host('globalThis.observed=[];globalThis.saved=performance.getEntries()[0];globalThis.observer=new PerformanceObserver(list=>observed.push(list.getEntries()[0]));observer.observe({type:"mark",buffered:true});')!
	caller.finish()
	mut main_queue := html.main_thread_event_loop().task_queue()
	for {
		task := main_queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .performance_timeline }) or { break }
		task.execute()
	}
	assert runtime.evaluate_host('observed.length')! == '0'
	mut delivery := platform.begin_thread_scratch('worker performance delivery')
	mut queue := environment.settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .performance_timeline }) or { break }
		task.execute()
	}
	delivery.finish()
	assert runtime.evaluate_host('observed.length===1&&observed[0]===saved&&saved.name==="buffered worker mark"&&saved.startTime===7')! == 'true'
	assert runtime.evaluate_host('observer.disconnect();performance.clearMarks();performance.getEntries().length')! == '0'
}

fn test_module_worker_entry_can_use_native_performance_before_its_first_message() {
	url := dom.URL{ value: 'https://worker-performance.test/entry.js' }
	transport := &fetch.FetchHost{ perform: fn (request &fetch.Request) !&fetch.Response {
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
		response.set_body_bytes('postMessage({now:performance.now(),origin:performance.timeOrigin,native:performance instanceof Performance,observer:typeof PerformanceObserver});'.bytes())
		return response
	} }
	mut agent := WorkerAgentRuntime.create(url, html.WorkerOptions{ type_: .module_ },
		html.SerializedEnvironmentSettingsObject{ creation_url: url, api_base_url: url, origin: url.origin(),
			policy_container: html.SerializedPolicyContainer{ referrer_policy: .strict_origin_when_cross_origin },
			global: html.SerializedWindow{ associated_document: html.SerializedDocument{ url: url, relevant_settings_object_is_secure_context: true } }
		}, highresolutiontime.unsafe_shared_current_time(), transport)!
	defer { agent.close() }
	agent.load_entry()!
	assert agent.state() == .ready
	assert agent.environment.settings.realm().reported_exceptions.len == 0
	frames := agent.take_outgoing()
	assert frames.len == 1
	mut receiver := Runtime.create()
	defer { receiver.close() }
	transfer := ArrayBufferTransferBridge.create(receiver)!
	actual := transfer.deserialize(decode_worker_message(frames[0])!)!
	receiver.define_value_host_function('__workerPerformance', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert receiver.evaluate_host('(()=>{const value=__workerPerformance();return value.native&&value.observer==="function"&&value.now>=0&&value.now<30000&&value.origin>0})()')! == 'true'
}

fn test_javascript_worker_marks_use_the_worker_clock_and_allow_navigation_timing_names() {
	for module_worker in [false, true] {
		mut runtime, environment := worker_performance_fixture(module_worker)!
		defer { runtime.close() }
		mut scope := environment.settings.window_or_worker_global_scope()!
		assert runtime.evaluate_host(r'
 globalThis.workerMark=performance.mark("navigationStart",{startTime:7,detail:{worker:true}});
 const direct=new PerformanceMark("connectStart",{startTime:9});
 workerMark instanceof PerformanceMark&&workerMark.startTime===7&&workerMark.detail.worker&&direct.name==="connectStart"&&
 performance.getEntriesByName("navigationStart")[0]===workerMark&&performance.getEntriesByName("connectStart").length===0;
 ')! == 'true'
		assert scope.performance().get_entries_by_name('navigationStart', 'mark').len == 1
		mut scratch := platform.begin_thread_scratch('worker mark detail')
		assert runtime.evaluate_host('workerMark.detail.worker')! == 'true'
		scratch.finish()
		gc_collect()
		assert runtime.evaluate_host('workerMark.detail.worker')! == 'true'
	}
}
