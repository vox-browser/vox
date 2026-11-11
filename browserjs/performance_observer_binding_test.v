module browserjs

import dom
import html
import loader
import performancetimeline
import platform
import usertiming

fn native_observer_fixture() !(&Runtime, &dom.Document, &html.WindowOrWorkerGlobalScopeMixin) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://observer-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_performance_observer_binding()!
	mut window := unsafe { &html.WindowModel(settings.global_object()) }
	return runtime, document, window.window_or_worker_global_scope()
}

fn drain_native_observer_binding(scope &html.WindowOrWorkerGlobalScopeMixin) {
	mut queue := scope.responsible_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .performance_timeline
		}) or { return }
		task.execute()
	}
	panic('PerformanceObserver tasks did not settle')
}

fn test_performance_observer_binding_delivers_native_entries_and_preserves_wrappers() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut scope := native_observer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.observer=new PerformanceObserver(function(list,receiver,options){
  const entries=list.getEntries();globalThis.saved=entries[0];
  log.push(this===observer,receiver===observer,list instanceof PerformanceObserverEntryList,entries.every(e=>e instanceof PerformanceEntry),entries.map(e=>e.name).join(","),list.getEntriesByType("mark").length,list.getEntriesByName("same","mark").length,list.getEntries()[0]===saved,options.droppedEntriesCount);
  log.push(JSON.stringify(saved.toJSON()));
 });observer.observe({entryTypes:["mark","resource"]});log.length===0;
 ')! == 'true'
	mut performance := scope.performance()
	performance.mark('same', usertiming.PerformanceMarkOptions{ start_time: 20 })!
	performance.mark('same', usertiming.PerformanceMarkOptions{ start_time: 3 })!
	performance.add_entry(performancetimeline.PerformanceEntry.new('resource', 'resource', 10, 2))
	drain_native_observer_binding(scope)
	assert runtime.evaluate_host('JSON.stringify(log)')! == r'[true,true,true,true,"same,resource,same",2,2,true,0,"{\"name\":\"same\",\"entryType\":\"mark\",\"startTime\":3,\"duration\":0}"]'
	assert runtime.evaluate_host(r'
 let failures=0;for(const read of [()=>PerformanceEntry.prototype.toJSON.call({}),()=>PerformanceObserverEntryList.prototype.getEntries.call({})]){try{read()}catch(e){if(e instanceof TypeError)failures++}}
 Object.prototype.toString.call(saved)==="[object PerformanceMark]"&&saved instanceof PerformanceMark&&failures===2&&observer.takeRecords().length===0;
 ')! == 'true'
}

fn test_performance_observer_binding_buffered_records_brands_and_conversion() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut scope := native_observer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut performance := scope.performance()
	performance.mark('before', usertiming.PerformanceMarkOptions{ start_time: 4 })!
	assert runtime.evaluate_host(r'
 globalThis.called=0;class Derived extends PerformanceObserver{};globalThis.observer=new Derived(()=>called++);observer.observe({type:"mark",buffered:true});
 const records=observer.takeRecords();let errors=0;
 for(const bad of [()=>PerformanceObserver(()=>{}),()=>new PerformanceObserver({handleEvent(){}}),()=>observer.observe(),()=>observer.observe({}),()=>observer.observe({entryTypes:["mark"],buffered:false}),()=>PerformanceObserver.prototype.disconnect.call({}),()=>new PerformanceEntry(),()=>new PerformanceObserverEntryList()]){try{bad()}catch(e){if(e instanceof TypeError)errors++}}
 let mode=false;try{observer.observe({entryTypes:["mark"]})}catch(e){mode=e instanceof DOMException&&e.name==="InvalidModificationError"}
 const marker={};let same=false;try{observer.observe({get type(){throw marker}})}catch(e){same=e===marker}
 globalThis.order=[];observer.observe({get buffered(){order.push("buffered");return false},get durationThreshold(){order.push("threshold");return {valueOf(){order.push("value");return 1}}},get entryTypes(){order.push("entries")},get type(){order.push("type");return "unsupported"}});
 records.length===1&&records[0].name==="before"&&observer instanceof Derived&&Object.isFrozen(PerformanceObserver.supportedEntryTypes)&&PerformanceObserver.supportedEntryTypes===PerformanceObserver.supportedEntryTypes&&PerformanceObserver.supportedEntryTypes.join(",")==="mark,measure,resource,visibility-state"&&errors===8&&mode&&same&&order.join(",")==="buffered,threshold,value,entries,type";
 ')! == 'true'
	drain_native_observer_binding(scope)
	assert runtime.evaluate_host('called')! == '0'
}

fn test_performance_observer_binding_reentrant_disconnect_exceptions_and_close_are_safe() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut scope := native_observer_fixture()!
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.first=new PerformanceObserver(()=>{log.push("first");first.disconnect();second.disconnect();globalThis.late=new PerformanceObserver(()=>log.push("late"));late.observe({type:"mark"});throw new Error("observer listener failed")});
 globalThis.second=new PerformanceObserver(()=>log.push("second"));first.observe({type:"mark"});second.observe({type:"mark"});true;
 ')! == 'true'
	mut performance := scope.performance()
	performance.mark('first', usertiming.PerformanceMarkOptions{ start_time: 1 })!
	drain_native_observer_binding(scope)
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["first"]'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	mut temporary := platform.begin_thread_scratch('performance observer caller')
	source := 'globalThis.pending=new PerformanceObserver(()=>log.push("pending"));pending.observe({type:"mark",buffered:true});true'.clone()
	temporary.leave()
	assert runtime.evaluate_host(source)! == 'true'
	temporary.finish()
	gc_collect()
	drain_native_observer_binding(scope)
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["first","pending"]'
	performance.mark('next', usertiming.PerformanceMarkOptions{ start_time: 2 })!
	runtime.close()
	drain_native_observer_binding(scope)
	document.finalize()
}

fn test_performance_observer_empty_records_are_real_engine_arrays() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := native_observer_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const observer=new PerformanceObserver(()=>{});
 const first=observer.takeRecords(),second=observer.takeRecords();
 Array.isArray(first)&&first.length===0&&Array.isArray(second)&&second.length===0&&first!==second;
 ')! == 'true'
}
