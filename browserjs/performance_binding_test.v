module browserjs

import dom
import html
import loader
import highresolutiontime
import performancetimeline
import usertiming

fn native_performance_fixture() !(&Runtime, &dom.Document, &html.WindowOrWorkerGlobalScopeMixin) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://performance-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut window := unsafe { &html.WindowModel(settings.global_object()) }
	return runtime, document, window.window_or_worker_global_scope()
}

fn drain_native_performance_binding(scope &html.WindowOrWorkerGlobalScopeMixin) {
	mut queue := scope.responsible_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .performance_timeline
		}) or { return }
		task.execute()
	}
	panic('Performance tasks did not settle')
}

fn test_performance_binding_uses_owning_clock_and_shared_observer_wrappers() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_performance_binding()!
	runtime.install_performance_binding()!
	mut performance := scope.performance()
	performance.mark('later', usertiming.PerformanceMarkOptions{ start_time: 20 })!
	performance.mark('first', usertiming.PerformanceMarkOptions{ start_time: 3 })!
	assert runtime.evaluate_host(r'
 globalThis.saved=performance.getEntries()[0];globalThis.received=null;
 globalThis.observer=new PerformanceObserver(list=>received=list.getEntries()[0]);observer.observe({type:"mark",buffered:true});
 const entries=performance.getEntries(),snapshot=JSON.parse(JSON.stringify(performance));
 performance===globalThis.performance&&performance instanceof Performance&&performance instanceof EventTarget&&Object.prototype.toString.call(performance)==="[object Performance]"&&entries.map(e=>e.name).join(",")==="first,later"&&entries[0]===saved&&saved instanceof PerformanceEntry&&performance.getEntriesByType("mark")[0]===saved&&performance.getEntriesByName("first","mark")[0]===saved&&performance.getEntriesByType("unknown").length===0&&Object.keys(snapshot).join(",")==="timeOrigin"&&Number.isFinite(snapshot.timeOrigin);
 ')! == 'true'
	before := performance.now()
	now := runtime.evaluate_host('performance.now()')!.f64()
	after := performance.now()
	assert now >= before && now <= after
	origin := runtime.evaluate_host('performance.timeOrigin')!.f64()
	assert origin >= highresolutiontime.wall_clock_unsafe_current_time() - 60000
	assert origin <= highresolutiontime.wall_clock_unsafe_current_time() + 1
	drain_native_performance_binding(scope)
	assert runtime.evaluate_host('received===saved')! == 'true'
}

fn test_performance_binding_brands_before_conversion_and_clears_native_buffers() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_performance_binding()!
	mut performance := scope.performance()
	performance.mark('remove', usertiming.PerformanceMarkOptions{ start_time: 1 })!
	performance.mark('keep', usertiming.PerformanceMarkOptions{ start_time: 2 })!
	assert runtime.evaluate_host(r'
 globalThis.order=[];const text={toString(){order.push("string");return "remove"}};
 let brands=0;for(const call of [()=>Performance.prototype.getEntriesByName.call({},text),()=>Performance.prototype.now.call({}),()=>Object.getOwnPropertyDescriptor(Performance.prototype,"timeOrigin").get.call({}),()=>new Performance(),()=>performance.getEntriesByType(),()=>performance.setResourceTimingBufferSize()]){try{call()}catch(e){if(e instanceof TypeError)brands++}}
 const marker={};let same=false;try{performance.getEntriesByType({toString(){throw marker}})}catch(e){same=e===marker}
 const result=performance.clearMarks(text);performance.setResourceTimingBufferSize({valueOf(){order.push("size");return 2}});
 brands===6&&same&&result===undefined&&order.join(",")==="string,size"&&performance.getEntries()[0].name==="keep";
 ')! == 'true'
	assert performance.get_entries_by_name('remove', none).len == 0
	assert performance.resource_timing_buffer_size == 2
	assert runtime.evaluate_host('performance.clearMarks();performance.clearMeasures();performance.getEntries().length')! == '0'
	assert performance.get_entries().len == 0
	assert runtime.evaluate_host('globalThis.nativePerformance=performance;performance=123;performance===123&&nativePerformance instanceof Performance')! == 'true'
}

fn test_performance_binding_buffer_full_event_can_clear_and_reenter_native_timeline() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 globalThis.events=[];performance.setResourceTimingBufferSize(1);
 performance.addEventListener("resourcetimingbufferfull",function(event){events.push(this===performance,event.target===performance,event.isTrusted)});
 globalThis.handler=function(){events.push("handler");performance.clearResourceTimings()};performance.onresourcetimingbufferfull=handler;
 performance.onresourcetimingbufferfull===handler;
 ')! == 'true'
	mut performance := scope.performance()
	performance.add_entry(performancetimeline.PerformanceEntry.new('first', 'resource', 1, 0))
	performance.add_entry(performancetimeline.PerformanceEntry.new('second', 'resource', 2, 0))
	assert runtime.evaluate_host('events.length===0&&performance.getEntriesByType("resource")[0].name==="first"')! == 'true'
	drain_native_performance_binding(scope)
	assert runtime.evaluate_host('JSON.stringify(events)')! == '[true,true,true,"handler"]'
	assert runtime.evaluate_host('performance.getEntriesByType("resource")[0].name==="second"')! == 'true'
	assert runtime.evaluate_host('performance.onresourcetimingbufferfull=null;performance.onresourcetimingbufferfull===null')! == 'true'
}
