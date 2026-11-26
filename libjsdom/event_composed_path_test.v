// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import html
import dom
import os
import rand

fn path_binding_fixture(markup string) !(&Host, &libjs.VM) {
	document := html.parse_document_with_url(markup, dom.URL{ value: 'https://event_composed_path.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'path_binding')!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn path_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'event_composed_path.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_composed_path_returns_fresh_native_target_arrays_only_during_dispatch() {
	mut host, mut vm := path_binding_fixture('<body><div id="parent"><button id="child"></button></div></body>')!
	defer { host.close() }
	assert path_binding_eval(mut vm, 'var parent=document.getElementById("parent"),child=document.getElementById("child"),event=new Event("path",{bubbles:true}),valid=false;child.addEventListener("path",e=>{var first=e.composedPath(),second=e.composedPath();first.pop();valid=Array.isArray(first)&&first!==second&&second[0]===child&&second[1]===parent&&second.includes(document)&&first.length+1===second.length});var before=event.composedPath().length;child.dispatchEvent(event);valid&&before===0&&event.composedPath().length===0')!.as_bool()
	assert path_binding_eval(mut vm, 'var descriptor=Object.getOwnPropertyDescriptor(Event.prototype,"composedPath"),caught=false;try{descriptor.value.call({})}catch(error){caught=error instanceof TypeError}caught&&descriptor.enumerable&&descriptor.configurable&&descriptor.writable&&descriptor.value.length===0')!.as_bool()
}

fn test_composed_path_hides_closed_shadow_nodes_from_outside_listeners() {
	mut host, mut vm := path_binding_fixture('<body><div id="host"></div></body>')!
	defer { host.close() }
	assert path_binding_eval(mut vm, 'var element=document.getElementById("host"),root=element.attachShadow({mode:"closed"}),child=document.createElement("button");root.appendChild(child);var inside=false,outside=false;root.addEventListener("path",event=>{var path=event.composedPath();inside=path[0]===child&&path[1]===root&&path.includes(element)});document.addEventListener("path",event=>{var path=event.composedPath();outside=event.target===element&&path[0]===element&&!path.includes(child)&&!path.includes(root)});child.dispatchEvent(new Event("path",{bubbles:true,composed:true}));inside&&outside')!.as_bool()
}

fn test_composed_path_native_cache_reopen_wraps_the_current_document_targets() {
	directory := os.join_path(os.temp_dir(), 'vox-event-path-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := path_binding_fixture('<body><button id="child"></button></body>')!
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		assert path_binding_eval(mut vm, 'var child=document.getElementById("child"),valid=false;child.addEventListener("path",event=>{var path=event.composedPath();valid=path[0]===child&&path.includes(document.body)&&path.includes(document)});child.dispatchEvent(new Event("path",{bubbles:true}));valid')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_misses == 0 && stats.cache_hits > 0 && stats.compiler_invocations == 0 && activity.entries > 0
		}
		vm.close_native_code()!
		host.close()
	}
}
