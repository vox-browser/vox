module browserjs

import css
import dom
import html
import layout
import loader
import platform

fn intersection_binding_fixture() !(&Runtime, &dom.Document, &dom.Element) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://intersection-binding.test/' }
	mut document := html.parse_navigation_document('<!doctype html><html><body><div id="target" style="position:absolute;left:10px;top:20px;width:100px;height:50px"></div></body></html>', url, url.origin(), none)!
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut navigable := &dom.Navigable{ active_document_: document, is_top_level_traversable_: true }
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	layout.install_document_layout_hook(document)
	document.needs_full_layout_tree_update = true
	document.update_layout(.debugging)
	target := css.query_selector(unsafe { &dom.Node(document) }, '#target') or { return error('Target missing') }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_intersection_observer_binding(none)!
	runtime.bind_event_target(runtime.evaluate_host_value('globalThis.target={}')!, unsafe { &dom.EventTarget(target) })!
	runtime.bind_event_target(runtime.evaluate_host_value('globalThis.document={}')!, unsafe { &dom.EventTarget(document) })!
	return runtime, document, target
}

fn drain_intersection_binding_tasks() {
	mut queue := html.main_thread_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .intersection_observer
		}) or { return }
		task.execute()
	}
	panic('IntersectionObserver delivery did not settle')
}

fn test_intersection_binding_delivers_live_layout_transitions_and_native_rectangles() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut target := intersection_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.observer=new IntersectionObserver(function(entries,receiver){
  globalThis.entry=entries[0];log.push([this===observer,receiver===observer,entry instanceof IntersectionObserverEntry,entry.target===target,entry.isIntersecting,entry.intersectionRatio,entry.time,entry.boundingClientRect.x,entry.boundingClientRect.width]);
 },{threshold:[1,0.5,0],rootMargin:"0px"});observer.observe(target);observer.observe(target);
 observer.root===null&&observer.rootMargin==="0px 0px 0px 0px"&&Object.isFrozen(observer.thresholds)&&observer.thresholds.join(",")==="0,0.5,1"&&log.length===0;
 ')! == 'true'
	document.run_the_update_intersection_observations_steps(100)
	assert runtime.evaluate_host('log.length')! == '0'
	drain_intersection_binding_tasks()
	assert runtime.evaluate_host(r'
 JSON.stringify(log)==="[[true,true,true,true,true,1,100,10,100]]"&&entry.rootBounds instanceof DOMRectReadOnly&&entry.rootBounds.width===800&&entry.boundingClientRect instanceof DOMRectReadOnly&&entry.boundingClientRect===entry.boundingClientRect&&entry.intersectionRect.height===50&&Object.prototype.toString.call(entry)==="[object IntersectionObserverEntry]";
 ')! == 'true'
	document.run_the_update_intersection_observations_steps(101)
	drain_intersection_binding_tasks()
	assert runtime.evaluate_host('log.length')! == '1'
	target.set_attribute_value('style', 'position:absolute;left:900px;top:20px;width:100px;height:50px')
	mut node := target.as_node()
	node.set_needs_layout_tree_update(true, .style_change)
	document.update_layout(.debugging)
	document.run_the_update_intersection_observations_steps(102)
	drain_intersection_binding_tasks()
	assert runtime.evaluate_host('log.length===2&&log[1][4]===false&&log[1][5]===0&&log[1][7]===900&&observer.takeRecords().length===0')! == 'true'
	assert runtime.evaluate_host('observer.unobserve(target);true')! == 'true'
}

fn test_intersection_binding_webidl_order_brands_and_original_exceptions() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := intersection_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.order=[];const options={};
 for(const name of ["delay","root","rootMargin","scrollMargin","threshold","trackVisibility"])Object.defineProperty(options,name,{get(){order.push(name);return ({delay:3,root:document,rootMargin:"1px 2%",scrollMargin:"5px",threshold:[],trackVisibility:true})[name]}});
 class Derived extends IntersectionObserver{};globalThis.observer=new Derived(()=>{},options);
 let errors=0;for(const run of [()=>IntersectionObserver(()=>{}),()=>new IntersectionObserver(),()=>new IntersectionObserver({handleEvent(){}}),()=>new IntersectionObserver(()=>{},1),()=>observer.observe(),()=>observer.observe(document),()=>observer.observe(new Proxy(target,{})),()=>IntersectionObserver.prototype.disconnect.call({}),()=>Object.getOwnPropertyDescriptor(IntersectionObserverEntry.prototype,"target").get.call({}),()=>new IntersectionObserver(()=>{},{threshold:NaN}),()=>new IntersectionObserver(()=>{},{threshold:1n})])try{run()}catch(e){if(e instanceof TypeError)errors++}
 let syntax=false,range=false,same=false;const marker={};
 try{new IntersectionObserver(()=>{},{rootMargin:"bad"})}catch(e){syntax=e instanceof DOMException&&e.name==="SyntaxError"}
 try{new IntersectionObserver(()=>{},{threshold:1.5})}catch(e){range=e instanceof RangeError}
 try{new IntersectionObserver(()=>{},{get rootMargin(){throw marker}})}catch(e){same=e===marker}
 let iteratorReads=0,closed=false;const thresholds={get [Symbol.iterator](){iteratorReads++;return function(){let n=0;return {next(){return {done:false,value:n++?Infinity:0}},return(){closed=true;return {done:true}}}}}};
 try{new IntersectionObserver(()=>{},{threshold:thresholds})}catch(e){}
 errors===11&&syntax&&range&&same&&closed&&iteratorReads===1&&observer instanceof Derived&&observer.root===document&&observer.rootMargin==="1px 2% 1px 2%"&&observer.scrollMargin==="5px 5px 5px 5px"&&observer.thresholds.join(",")==="0"&&observer.delay===100&&observer.trackVisibility&&order.join(",")==="delay,root,rootMargin,scrollMargin,threshold,trackVisibility";
 ')! == 'true'
}

fn test_intersection_binding_take_records_reentrant_callback_and_runtime_close() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := intersection_binding_fixture()!
	defer { document.finalize() }
	baseline := document.registered_intersection_observer_count()
	owned_before := runtime.owned_closures_.len
	mut temporary := platform.begin_thread_scratch('intersection observer caller')
	source := 'globalThis.calls=0;globalThis.observer=new IntersectionObserver(function(){calls++;observer.disconnect();throw new Error("observer callback failed")});observer.observe(target);true'.clone()
	temporary.leave()
	assert runtime.evaluate_host(source)! == 'true'
	assert runtime.owned_closures_.len == owned_before + 1
	temporary.finish()
	gc_collect()
	document.run_the_update_intersection_observations_steps(10)
	assert runtime.evaluate_host('globalThis.records=observer.takeRecords();records.length===1&&records[0].target===target&&observer.takeRecords().length===0')! == 'true'
	drain_intersection_binding_tasks()
	assert runtime.evaluate_host('calls')! == '0'
	assert runtime.evaluate_host('observer.disconnect();observer.observe(target);true')! == 'true'
	document.run_the_update_intersection_observations_steps(20)
	drain_intersection_binding_tasks()
	assert runtime.evaluate_host('calls')! == '1'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.evaluate_host('observer.observe(target);true')! == 'true'
	document.run_the_update_intersection_observations_steps(30)
	assert document.registered_intersection_observer_count() == baseline + 1
	runtime.close()
	assert runtime.owned_closures_.len == 0
	assert document.registered_intersection_observer_count() == baseline
	drain_intersection_binding_tasks()
}
