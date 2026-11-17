module libjsdom

import dom
import html
import libjs
import os
import rand

fn inline_handler_fixture(markup string) !(&Host, &libjs.VM) {
	address := dom.URL{value: 'https://inline-handler.test/'}
	document := html.parse_navigation_document(markup, address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	return Host.create(vm, vm.realm(), document, Hooks{})!, vm
}

fn inline_handler_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'inline-check.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or {
		return error(exception_message_with_stack(err))
	}
}

fn test_raw_handlers_compile_lazily_with_native_event_receiver_and_false_cancellation() {
	mut host, mut vm := inline_handler_fixture('<button id="target" onclick="calls++;identity=this===target&amp;&amp;event.target===target;return false">click</button>')!
	defer { host.close() }
	assert inline_handler_eval(mut vm, 'var target=document.getElementById("target"),calls=0,identity=false;target.onclick===target.onclick&&target.onclick.name==="onclick"&&target.onclick.length===1')!.as_bool()
	event := dom.Event.create('click', dom.EventInit{bubbles: true, cancelable: true})
	unsafe { &dom.EventTarget(host.document.get_element_by_id('target')?) }.dispatch_event(event)
	assert event.default_prevented()
	assert inline_handler_eval(mut vm, 'calls===1&&identity')!.as_bool()
}

fn test_raw_handlers_use_element_form_document_global_scope_and_mutation_recompiles() {
	mut host, mut vm := inline_handler_fixture('<form id="form"><button id="target" type="button" onclick="observed=scopeMarker">click</button></form>')!
	defer { host.close() }
	assert inline_handler_eval(mut vm, 'var target=document.getElementById("target"),form=document.getElementById("form"),scopeMarker="global",observed="";document.scopeMarker="document";form.scopeMarker="form";target.scopeMarker="element";target.click();observed==="element"')!.as_bool()
	assert inline_handler_eval(mut vm, 'delete target.scopeMarker;target.click();observed==="form"')!.as_bool()
	assert inline_handler_eval(mut vm, 'delete form.scopeMarker;target.click();observed==="document"')!.as_bool()
	assert inline_handler_eval(mut vm, 'delete document.scopeMarker;target.click();observed==="global"')!.as_bool()
	assert inline_handler_eval(mut vm, 'var old=target.onclick;target.setAttribute("onclick","observed=42");target.click();observed===42&&target.onclick!==old')!.as_bool()
	assert inline_handler_eval(mut vm, 'target.setAttribute("onclick","return }");target.onclick===null')!.as_bool()
	assert inline_handler_eval(mut vm, 'target.onclick=function(){observed=43};target.click();observed===43')!.as_bool()
	assert inline_handler_eval(mut vm, 'target.setAttribute("onclick","observed=44");target.onclick();observed===44')!.as_bool()
}

fn test_click_uses_native_disabled_and_recursion_guards_and_close_retires_raw_handlers() {
	mut host, mut vm := inline_handler_fixture('<button id="target" onclick="calls++;this.click()">click</button><button id="disabled" disabled onclick="calls+=100">disabled</button>')!
	defer { host.close() }
	assert inline_handler_eval(mut vm, 'var target=document.getElementById("target"),calls=0;target.click();document.getElementById("disabled").click();calls===1')!.as_bool()
	target := unsafe { &dom.EventTarget(host.document.get_element_by_id('target')?) }
	assert target.get_current_value_of_event_handler('click') != none
	host.close()
	assert target.get_current_value_of_event_handler('click') == none
	target.dispatch_event(dom.Event.create('click', dom.EventInit{}))
	assert inline_handler_eval(mut vm, 'calls===1')!.as_bool()
}

fn test_cached_raw_handlers_use_the_new_document_and_vm_without_a_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-inline-handler-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := inline_handler_fixture('<button id="target" onclick="this.textContent=String(Number(this.textContent)+1)">41</button>')!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		assert inline_handler_eval(mut vm, 'var target=document.getElementById("target");target.click();target.textContent==="42"')!.as_bool()
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 }
		host.close()
		vm.close_native_code()!
	}
}
