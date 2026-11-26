// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import layout
import libjs
import loader
import os
import rand

@[heap]
struct IntersectionErrors {
mut:
	values []string
}

fn intersection_fixture() !(&Host, &libjs.VM, &dom.Document, &IntersectionErrors) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{value: 'https://intersection-libjs.test/'}
	mut document := html.parse_navigation_document('<body><div id="target" style="position:absolute;left:10px;top:20px;width:100px;height:50px"></div></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut navigable := &dom.Navigable{active_document_: document, is_top_level_traversable_: true}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	layout.install_document_layout_hook(document)
	document.needs_full_layout_tree_update = true
	document.update_layout(.debugging)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	errors := &IntersectionErrors{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{exception: fn [errors] (message string) {
		mut state := unsafe { &IntersectionErrors(errors) }; state.values << message
	}})!
	return host, vm, document, errors
}

fn intersection_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-intersection-observer.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn intersection_tasks() {
	mut queue := html.main_thread_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .intersection_observer }) or { return }
		task.execute()
	}
	panic('IntersectionObserver delivery did not settle')
}

fn test_native_intersection_observer_delivers_layout_transitions_and_actual_entry_geometry() {
	mut host, mut vm, mut document, errors := intersection_fixture()!
	defer { host.close(); document.finalize() }
	assert intersection_eval(mut vm, 'var calls=0,entry,identity=false,target=document.getElementById("target");class O extends IntersectionObserver{answer=42}var observer=new O(function(records,self){calls++;entry=records[0];identity=this===observer&&self===observer},{threshold:[1,0.5,0]});observer.observe(target);observer.observe(target);observer instanceof O&&observer.answer===42&&observer.root===null&&observer.rootMargin==="0px 0px 0px 0px"&&Object.isFrozen(observer.thresholds)&&observer.thresholds.join(",")==="0,0.5,1"&&calls===0')!.as_bool()
	document.run_the_update_intersection_observations_steps(100)
	assert intersection_eval(mut vm, 'calls===0')!.as_bool()
	intersection_tasks()
	assert intersection_eval(mut vm, 'calls===1&&identity&&entry instanceof IntersectionObserverEntry&&entry.target===target&&entry.isIntersecting&&entry.intersectionRatio===1&&entry.time===100&&entry.rootBounds instanceof DOMRectReadOnly&&entry.rootBounds.width===800&&entry.boundingClientRect.x===10&&entry.boundingClientRect.width===100&&entry.boundingClientRect===entry.boundingClientRect&&entry.intersectionRect.height===50&&Object.prototype.toString.call(entry)==="[object IntersectionObserverEntry]"')!.as_bool()
	document.run_the_update_intersection_observations_steps(101)
	intersection_tasks()
	assert intersection_eval(mut vm, 'calls===1')!.as_bool()
	mut target := unsafe { &dom.Element(document.get_element_by_id('target')?) }
	target.set_attribute_value('style', 'position:absolute;left:900px;top:20px;width:100px;height:50px')
	mut node := target.as_node()
	node.set_needs_layout_tree_update(true, .style_change)
	document.update_layout(.debugging)
	document.run_the_update_intersection_observations_steps(102)
	intersection_tasks()
	assert intersection_eval(mut vm, 'calls===2&&!entry.isIntersecting&&entry.intersectionRatio===0&&entry.boundingClientRect.x===900&&observer.takeRecords().length===0')!.as_bool()
	assert errors.values.len == 0
}

fn test_intersection_observer_dictionary_order_defaults_brands_and_original_exceptions() {
	mut host, mut vm, mut document, errors := intersection_fixture()!
	defer { host.close(); document.finalize() }
	assert intersection_eval(mut vm, 'var order="",options={get delay(){order+="d";return 3},get root(){order+="r";return document},get rootMargin(){order+="m";return "1px 2%"},get scrollMargin(){order+="s";return "5px"},get threshold(){order+="t";return []},get trackVisibility(){order+="v";return true}};var observer=new IntersectionObserver(()=>{},options);order==="drmstv"&&observer.root===document&&observer.rootMargin==="1px 2% 1px 2%"&&observer.scrollMargin==="5px 5px 5px 5px"&&observer.delay===100&&observer.trackVisibility&&observer.thresholds.join(",")==="0"')!.as_bool()
	assert intersection_eval(mut vm, 'var n=0;for(var run of [()=>IntersectionObserver(()=>{}),()=>new IntersectionObserver(),()=>new IntersectionObserver({}),()=>new IntersectionObserver(()=>{},1),()=>observer.observe(),()=>observer.observe(document),()=>IntersectionObserver.prototype.disconnect.call({}),()=>Object.getOwnPropertyDescriptor(IntersectionObserverEntry.prototype,"target").get.call({}),()=>new IntersectionObserver(()=>{},{threshold:NaN}),()=>new IntersectionObserver(()=>{},{threshold:1n}),()=>new IntersectionObserverEntry()])try{run()}catch(e){if(e instanceof TypeError)n++}n===11')!.as_bool()
	assert intersection_eval(mut vm, 'var syntax=false,range=false,same=false,reason={};try{new IntersectionObserver(()=>{},{rootMargin:"bad",threshold:2})}catch(e){syntax=e instanceof DOMException&&e.name==="SyntaxError"}try{new IntersectionObserver(()=>{},{threshold:1.5})}catch(e){range=e instanceof RangeError}try{new IntersectionObserver(()=>{},{get rootMargin(){throw reason}})}catch(e){same=e===reason}syntax&&range&&same')!.as_bool()
	assert errors.values.len == 0
}

fn test_intersection_threshold_sequence_closes_on_conversion_failure_without_double_iterator_get() {
	mut host, mut vm, mut document, _ := intersection_fixture()!
	defer { host.close(); document.finalize() }
	assert intersection_eval(mut vm, 'var reads=0,closed=0,caught=false,threshold={get [Symbol.iterator](){reads++;return function(){var n=0;return {next(){return {value:n++?Infinity:0}},return(){closed++;return {}}}}}};try{new IntersectionObserver(()=>{},{threshold})}catch(e){caught=e instanceof TypeError}caught&&reads===1&&closed===1')!.as_bool()
	assert intersection_eval(mut vm, 'var reason={},same=false,threshold={};threshold[Symbol.iterator]=function(){return {next(){return {value:{valueOf(){throw reason}}}},return(){closed++;throw 99}}};try{new IntersectionObserver(()=>{},{threshold})}catch(e){same=e===reason}same&&closed===2')!.as_bool()
}

fn test_intersection_take_records_callback_errors_reentrancy_and_close_remove_native_registrations() {
	mut host, mut vm, mut document, errors := intersection_fixture()!
	defer { host.close(); document.finalize() }
	baseline := document.registered_intersection_observer_count()
	intersection_eval(mut vm, 'var calls=0,target=document.getElementById("target"),observer=new IntersectionObserver(function(){calls++;observer.disconnect();throw new Error("intersection failure")});observer.observe(target)')!
	document.run_the_update_intersection_observations_steps(10)
	assert intersection_eval(mut vm, 'var records=observer.takeRecords();records.length===1&&records[0].target===target&&observer.takeRecords().length===0')!.as_bool()
	intersection_tasks()
	assert intersection_eval(mut vm, 'calls===0')!.as_bool()
	intersection_eval(mut vm, 'observer.disconnect();observer.observe(target)')!
	document.run_the_update_intersection_observations_steps(20)
	intersection_tasks()
	assert intersection_eval(mut vm, 'calls===1')!.as_bool()
	assert errors.values.len == 1 && errors.values[0].contains('intersection failure')
	intersection_eval(mut vm, 'observer.observe(target)')!
	document.run_the_update_intersection_observations_steps(30)
	assert document.registered_intersection_observer_count() == baseline + 1
	host.close()
	assert document.registered_intersection_observer_count() == baseline
	intersection_tasks()
	assert errors.values.len == 1
}

fn test_cached_intersection_callback_runs_in_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-native-intersection-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, errors := intersection_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		intersection_eval(mut vm, 'var count=0;var observer=new IntersectionObserver(function(records){count+=records.length});observer.observe(document.getElementById("target"))')!
		document.run_the_update_intersection_observations_steps(100)
		intersection_tasks()
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('count'))!.number == 1
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert errors.values.len == 0
		vm.close_native_code()!
		host.close()
		document.finalize()
	}
}
