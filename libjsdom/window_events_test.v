// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn window_event_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'window-events.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn window_event_document() !&dom.Document {
	address := dom.URL{value: 'https://window-events.test/'}
	mut document := html.parse_navigation_document('<body><button id="a">a</button></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	return document
}

fn test_window_listeners_use_native_window_and_share_node_propagation() {
	mut document := window_event_document()!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert window_event_eval(mut vm, 'var calls=0,identity=false,order="",a=document.getElementById("a");function page(e){calls++;identity=this===window&&e.target===window&&e.currentTarget===window;e.preventDefault()}window.addEventListener("pageshow",page,{once:true});window.addEventListener("pageshow",page,{once:true});window.addEventListener("click",function(e){order+="c";identity=identity&&e.target===a&&e.currentTarget===window&&this===window},true);a.addEventListener("click",function(){order+="a"});window.addEventListener("click",function(){order+="b"});typeof window.addEventListener==="function"')!.as_bool()
	window := document.get_window()?
	target := unsafe { &dom.EventTarget(window) }
	first := dom.Event.create('pageshow', dom.EventInit{cancelable: true})
	dom.EventDispatcher.dispatch(target, first, false)
	assert first.default_prevented()
	dom.EventDispatcher.dispatch(target, dom.Event.create('pageshow', dom.EventInit{}), false)
	button := unsafe { &dom.EventTarget(document.get_element_by_id('a')?) }
	button.dispatch_event(dom.Event.create('click', dom.EventInit{bubbles: true}))
	assert window_event_eval(mut vm, 'calls===1&&identity&&order==="cab"')!.as_bool()
}

fn test_window_listener_receivers_removal_callback_objects_and_close() {
	mut document := window_event_document()!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	window_event_eval(mut vm, 'var n=0,objectThis=false,listener={handleEvent:function(e){n++;objectThis=this===listener&&e.currentTarget===window}};addEventListener("pagehide",listener);window.addEventListener("pagehide",listener,true);window.removeEventListener("pagehide",listener,false);var add=document.addEventListener;add.call(window,"passive",function(e){e.preventDefault()},{passive:true});var remove=window.removeEventListener;remove.call(window,"pagehide",listener,true);add.call(null,"pagehide",listener)')!
	target := unsafe { &dom.EventTarget(document.get_window()?) }
	target.dispatch_event(dom.Event.create('pagehide', dom.EventInit{}))
	passive := dom.Event.create('passive', dom.EventInit{cancelable: true})
	target.dispatch_event(passive)
	assert !passive.default_prevented()
	assert window_event_eval(mut vm, 'n===1&&objectThis')!.as_bool()
	for source in ['window.addEventListener.call({},"x",null)', 'window.addEventListener("x")', 'window.addEventListener("x",42)'] {
		assert window_event_eval(mut vm, 'var caught=false;try{'+source+'}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	}
	host.close()
	assert target.data.event_listener_list.len == 0
	target.dispatch_event(dom.Event.create('pagehide', dom.EventInit{}))
	assert window_event_eval(mut vm, 'n===1')!.as_bool()
}

fn test_cached_window_listener_executes_in_a_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-window-event-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut document := window_event_document()!
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), document, Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		window_event_eval(mut vm, 'var received=0;window.addEventListener("pageshow",function(e){if(this===window&&e.currentTarget===window)received++},{once:true})')!
		target := unsafe { &dom.EventTarget(document.get_window()?) }
		dom.EventDispatcher.dispatch(target, dom.Event.create('pageshow', dom.EventInit{}), false)
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('received'))!.number == 1
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
