module browserjs

import dom
import html
import loader
import highresolutiontime
import performancetimeline
import usertiming

fn C.JSGarbageCollect(context voidptr)

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

fn test_javascript_marks_use_the_native_clock_timeline_and_mark_interface() {
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	mut performance := scope.performance()
	before := performance.now()
	assert runtime.evaluate_host(r'
 globalThis.clockMark=performance.mark("clock");
 globalThis.explicitMark=performance.mark("explicit",{startTime:12});
 const descriptor=Object.getOwnPropertyDescriptor(Performance.prototype,"mark");
 clockMark instanceof PerformanceMark&&clockMark instanceof PerformanceEntry&&Object.prototype.toString.call(clockMark)==="[object PerformanceMark]"&&
 PerformanceMark.prototype.constructor===PerformanceMark&&Object.getPrototypeOf(PerformanceMark)===PerformanceEntry&&
 descriptor.enumerable&&descriptor.writable&&descriptor.configurable&&performance.mark.length===1&&PerformanceMark.length===1&&
 explicitMark===performance.getEntriesByName("explicit","mark")[0]&&explicitMark.startTime===12&&explicitMark.duration===0&&explicitMark.detail===null;
 ')! == 'true'
	after := performance.now()
	marks := performance.get_entries_by_name('clock', 'mark')
	assert marks.len == 1
	assert marks[0].start_time() >= before && marks[0].start_time() <= after
	assert performance.get_entries_by_name('explicit', 'mark')[0].start_time() == 12
}

fn test_performance_mark_constructor_keeps_entries_out_of_the_timeline_and_supports_subclasses() {
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 class ChildMark extends PerformanceMark{}
 const direct=new PerformanceMark("direct",{startTime:3,detail:{answer:42}}),child=new ChildMark("child",{startTime:4});
 function Other(){};Other.prototype=7;
 const fallback=Reflect.construct(PerformanceMark,["fallback"],Other);
 const json=PerformanceEntry.prototype.toJSON.call(direct);
 direct.name==="direct"&&direct.entryType==="mark"&&direct.startTime===3&&direct.duration===0&&direct.detail.answer===42&&
 child instanceof ChildMark&&child instanceof PerformanceMark&&Object.getPrototypeOf(child)===ChildMark.prototype&&
 Object.getPrototypeOf(fallback)===PerformanceMark.prototype&&performance.getEntries().length===0&&
 Object.keys(json).join(",")==="name,entryType,startTime,duration";
 ')! == 'true'
	assert scope.performance().get_entries().len == 0
}

fn test_performance_mark_detail_is_cloned_on_creation_and_every_read() {
	mut runtime, mut document, _ := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 const shared={answer:42},source={shared,again:shared,number:18446744073709551616n,map:new Map([["key",shared]]),bytes:new Uint8Array([1,2,3])};source.self=source;
 globalThis.detailMark=performance.mark("detail",{detail:source,startTime:1});
 source.shared.answer=99;source.bytes[0]=8;
 const first=detailMark.detail;first.shared.answer=7;first.bytes[0]=6;
 const second=detailMark.detail;
 first!==source&&second!==first&&second.self===second&&second.shared===second.again&&second.shared!==shared&&
 second.shared.answer===42&&second.number===18446744073709551616n&&second.map.get("key")===second.shared&&
 second.bytes instanceof Uint8Array&&second.bytes[0]===1&&second.bytes[2]===3&&
 performance.mark("undefined",{detail:undefined}).detail===null&&performance.mark("null",{detail:null}).detail===null;
 ')! == 'true'
}

fn test_performance_mark_conversion_order_brands_and_failed_validation_do_not_publish_entries() {
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 globalThis.markOrder=[];const name={toString(){markOrder.push("name");return "ordered"}},detail={get value(){markOrder.push("clone");return 1}};
 const options={get detail(){markOrder.push("detail");return detail},get startTime(){markOrder.push("start");return {valueOf(){markOrder.push("number");return 2}}}};
 let brands=0;try{performance.mark.call({},name,options)}catch(e){if(e instanceof TypeError)brands++}
 const untouched=markOrder.length===0;performance.mark(name,options);
 const order=markOrder.join(",")==="name,detail,start,number,clone";
 let errors=0;
 for(const call of [()=>performance.mark(),()=>new PerformanceMark(),()=>PerformanceMark("x"),()=>performance.mark(Symbol("x")),
  ()=>performance.mark("x",1),()=>performance.mark("x",{startTime:-1}),()=>performance.mark("x",{startTime:Infinity}),
  ()=>performance.mark("x",{startTime:NaN}),()=>performance.mark("x",{startTime:1n}),()=>new performance.mark("x")]){
  try{call()}catch(e){if(e instanceof TypeError)errors++}
 }
 let reserved=false;try{performance.mark("navigationStart",{detail})}catch(e){reserved=e instanceof DOMException&&e.name==="SyntaxError"&&e.code===12}
 const zero=performance.mark("zero",{startTime:-0});
 brands===1&&untouched&&order&&errors===10&&reserved&&Object.is(zero.startTime,-0)&&
 performance.getEntries().length===2&&performance.getEntriesByName("x").length===0&&markOrder.length===5;
 ')! == 'true'
	assert scope.performance().get_entries().len == 2
}

fn test_performance_mark_exceptions_preserve_identity_and_leave_observers_and_buffers_empty() {
	mut runtime, mut document, mut scope := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 const marker={};globalThis.failedMarkObserver=new PerformanceObserver(()=>{});failedMarkObserver.observe({type:"mark"});
 let preserved=0;for(const call of [()=>performance.mark({toString(){throw marker}}),
  ()=>performance.mark("x",{get detail(){throw marker}}),()=>performance.mark("x",{get startTime(){throw marker}}),
  ()=>performance.mark("x",{startTime:{valueOf(){throw marker}}}),()=>performance.mark("x",{detail:{get nested(){throw marker}}})]){
  try{call()}catch(e){if(e===marker)preserved++}
 }
 let clones=0;for(const value of [()=>0,Symbol("detail")]){try{performance.mark("x",{detail:value})}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError")clones++}}
 let nested=0;try{performance.mark("x",{startTime:-1,detail:{get fail(){nested++;return 1}}})}catch(e){}
 preserved===5&&clones===2&&nested===0&&performance.getEntries().length===0&&failedMarkObserver.takeRecords().length===0;
 ')! == 'true'
	assert scope.performance().get_entries().len == 0
}

fn test_javascript_mark_observers_keep_the_same_wrapper_after_clear_and_collection() {
	mut runtime, mut document, scope := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 globalThis.markDeliveries=[];globalThis.markObserver=new PerformanceObserver(list=>markDeliveries.push(list.getEntries()[0]));markObserver.observe({type:"mark"});
 globalThis.observedMark=performance.mark("queued",{startTime:5,detail:{keep:42}});
 const same=performance.getEntriesByType("mark")[0]===observedMark;performance.clearMarks("queued");same&&performance.getEntries().length===0;
 ')! == 'true'
	gc_collect()
	C.JSGarbageCollect(runtime.context)
	drain_native_performance_binding(scope)
	assert runtime.evaluate_host('markDeliveries.length===1&&markDeliveries[0]===observedMark&&observedMark.detail.keep===42&&observedMark.name==="queued"')! == 'true'
}

fn test_mark_detail_reads_release_temporary_roots_and_keep_captured_clone_intrinsics() {
	mut runtime, mut document, _ := native_performance_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_performance_binding()!
	assert runtime.evaluate_host(r'
 globalThis.rootedMark=performance.mark("rooted",{detail:{map:new Map([["key",42]])}});
 globalThis.originalMapSet=Map.prototype.set;Map.prototype.set=()=>{throw new Error("author override")};
 rootedMark.detail.map.get("key")===42;
 ')! == 'true'
	before := runtime.protected_values_.len
	for _ in 0 .. 8 {
		assert runtime.evaluate_host('rootedMark.detail.map.get("key")')! == '42'
	}
	assert runtime.protected_values_.len == before
	runtime.evaluate_host('Map.prototype.set=originalMapSet')!
}
