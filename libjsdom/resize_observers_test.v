// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import layout
import libjs
import loader
import os
import platform
import rand

@[heap]
struct ResizeErrors {
mut:
	values []string
}

fn resize_fixture() !(&Host, &libjs.VM, &dom.Document, &ResizeErrors) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{value: 'https://resize-libjs.test/'}
	mut document := html.parse_navigation_document('<body><div id="target" style="width:100px;height:50px;padding:4px 6px;border:2px solid"></div></body>', address, address.origin(), none)!
	document.enable_native_storage()
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
	errors := &ResizeErrors{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{exception: fn [errors] (message string) {
		mut state := unsafe { &ResizeErrors(errors) }; state.values << message
	}})!
	return host, vm, document, errors
}

fn resize_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-resize-observer.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_native_resize_observer_delivers_live_boxes_frozen_sizes_and_stable_entry_snapshots() {
	mut host, mut vm, mut document, errors := resize_fixture()!
	defer { host.close(); document.finalize() }
	assert resize_eval(mut vm, 'var calls=0,entry,saved,identity=false,target=document.getElementById("target");class O extends ResizeObserver{answer=42}var observer=new O(function(records,self){calls++;entry=records[0];identity=this===observer&&self===observer});observer.observe(target);observer.observe(target);observer instanceof O&&observer.answer===42&&ResizeObserver.length===1&&calls===0')!.as_bool()
	document.gather_active_observations_at_depth(0)
	assert document.has_active_resize_observations()
	document.broadcast_active_resize_observations()
	assert resize_eval(mut vm, 'saved=entry;calls===1&&identity&&entry instanceof ResizeObserverEntry&&entry.target===target&&entry.contentRect instanceof DOMRectReadOnly&&entry.contentRect.x===6&&entry.contentRect.y===4&&entry.contentRect.width===100&&entry.contentRect.height===50&&entry.contentRect===entry.contentRect&&Object.isFrozen(entry.borderBoxSize)&&entry.borderBoxSize===entry.borderBoxSize&&entry.borderBoxSize[0] instanceof ResizeObserverSize&&entry.borderBoxSize[0].inlineSize===116&&entry.borderBoxSize[0].blockSize===62&&entry.contentBoxSize[0].inlineSize===100&&Object.prototype.toString.call(entry)==="[object ResizeObserverEntry]"&&Object.prototype.toString.call(entry.contentBoxSize[0])==="[object ResizeObserverSize]"')!.as_bool()
	mut target := unsafe { &dom.Element(document.get_element_by_id('target')?) }
	target.set_attribute_value('style', 'width:140px;height:50px;padding:4px 6px;border:2px solid')
	mut node := target.as_node()
	node.set_needs_layout_tree_update(true, .style_change)
	document.update_layout(.debugging)
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	assert resize_eval(mut vm, 'calls===2&&entry!==saved&&entry.contentRect.width===140&&saved.contentRect.width===100&&saved.borderBoxSize[0].inlineSize===116')!.as_bool()
	resize_eval(mut vm, 'observer.unobserve(target)')!
	assert document.registered_resize_observer_count() == 0 && errors.values.len == 0
}

fn test_resize_observer_webidl_brand_target_options_order_and_original_errors() {
	mut host, mut vm, mut document, errors := resize_fixture()!
	defer { host.close(); document.finalize() }
	assert resize_eval(mut vm, 'var observer=new ResizeObserver(()=>{}),target=document.getElementById("target"),n=0;for(var run of [()=>ResizeObserver(()=>{}),()=>new ResizeObserver(),()=>new ResizeObserver({}),()=>new ResizeObserverEntry(),()=>new ResizeObserverSize(),()=>observer.observe(),()=>observer.unobserve(),()=>observer.observe(document),()=>ResizeObserver.prototype.disconnect.call({}),()=>ResizeObserver.prototype.observe.call({},target),()=>observer.observe(target,1),()=>observer.observe(target,{box:"bad"}),()=>observer.observe(target,{box:Symbol()}),()=>Object.getOwnPropertyDescriptor(ResizeObserverEntry.prototype,"target").get.call({}),()=>Object.getOwnPropertyDescriptor(ResizeObserverSize.prototype,"inlineSize").get.call({})])try{run()}catch(e){if(e instanceof TypeError)n++}n===15')!.as_bool()
	assert resize_eval(mut vm, 'var reads=0,reason={},same=false,options={get box(){reads++;throw reason}};try{observer.observe(document,options)}catch(e){}var brandedFirst=reads===0;try{observer.observe(target,options)}catch(e){same=e===reason}var conversions=0;observer.observe(target,{box:{toString(){conversions++;return "border-box"}}});observer.observe(target,null);observer.observe(target);brandedFirst&&reads===1&&same&&conversions===1&&observer.disconnect()===undefined')!.as_bool()
	assert document.registered_resize_observer_count() == 0 && errors.values.len == 0
}

fn test_resize_observer_box_selection_callback_reentrancy_errors_and_close_cleanup() {
	mut host, mut vm, mut document, errors := resize_fixture()!
	defer { host.close(); document.finalize() }
	resize_eval(mut vm, 'var target=document.getElementById("target"),contentCalls=0,borderCalls=0,content=new ResizeObserver(()=>{contentCalls++}),border=new ResizeObserver(()=>{borderCalls++});content.observe(target);border.observe(target,{box:"border-box"})')!
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	mut target := unsafe { &dom.Element(document.get_element_by_id('target')?) }
	target.set_attribute_value('style', 'width:100px;height:50px;padding:8px;border:2px solid')
	mut node := target.as_node()
	node.set_needs_layout_tree_update(true, .style_change)
	document.update_layout(.debugging)
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	assert resize_eval(mut vm, 'contentCalls===1&&borderCalls===2')!.as_bool()
	resize_eval(mut vm, 'content.disconnect();border.disconnect();var calls=0,broken=new ResizeObserver(function(){calls++;broken.disconnect();throw new Error("resize failure")});broken.observe(target)')!
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	assert resize_eval(mut vm, 'calls===1')!.as_bool()
	assert errors.values.len == 1 && errors.values[0].contains('resize failure')
	resize_eval(mut vm, 'broken.observe(target)')!
	document.gather_active_observations_at_depth(0)
	assert document.registered_resize_observer_count() == 1
	host.close()
	assert document.registered_resize_observer_count() == 0
	document.broadcast_active_resize_observations()
	assert errors.values.len == 1
}

fn test_resize_observer_retains_records_across_caller_scratch_lifetime() {
	mut host, mut vm, mut document, errors := resize_fixture()!
	defer { host.close(); document.finalize() }
	mut scratch := platform.begin_thread_scratch('LibJS resize caller')
	source := 'var calls=0,entry;var observer=new ResizeObserver(function(records){calls++;entry=records[0]});observer.observe(document.getElementById("target"))'.clone()
	scratch.leave()
	resize_eval(mut vm, source)!
	scratch.finish()
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	assert resize_eval(mut vm, 'calls===1&&entry.contentRect.width===100&&entry.borderBoxSize[0].inlineSize===116')!.as_bool()
	assert errors.values.len == 0
}

fn test_cached_resize_observer_callback_runs_in_a_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-native-resize-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, errors := resize_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		resize_eval(mut vm, 'var count=0;var observer=new ResizeObserver(function(records){count+=records.length});observer.observe(document.getElementById("target"))')!
		document.gather_active_observations_at_depth(0)
		document.broadcast_active_resize_observations()
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
