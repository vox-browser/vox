// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import html
import libjs

fn focus_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document_with_url('<body><button id="first">first</button><button id="second">second</button><button id="disabled" disabled>disabled</button></body>', dom.URL{ value: 'https://focus-binding.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'focus-bindings')!
	_ = css.css_style_computer_for(document)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn focus_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-element-focus.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_script_focus_runs_native_focus_events_and_blur_updates_the_active_element() {
	mut host, mut vm := focus_binding_fixture()!
	defer { host.close() }
	assert focus_binding_eval(mut vm, 'var first=document.getElementById("first"),second=document.getElementById("second"),events=[];for(var e of [first,second]){e.addEventListener("focus",event=>events.push("focus:"+event.target.id+":"+event.isTrusted));e.addEventListener("blur",event=>events.push("blur:"+event.target.id))}first.focus({preventScroll:true});var one=document.activeElement===first;second.focus({preventScroll:true});var two=document.activeElement===second;second.blur();one&&two&&document.activeElement===document.body&&events.join()==="focus:first:true,blur:first,focus:second:true,blur:second"')!.as_bool()
	assert focus_binding_eval(mut vm, 'first.focus({preventScroll:true});document.getElementById("disabled").focus();document.activeElement===first&&first.tabIndex===0')!.as_bool()
}

fn test_focus_options_coercion_preserves_original_errors_and_native_tabindex_reflection() {
	mut host, mut vm := focus_binding_fixture()!
	defer { host.close() }
	assert focus_binding_eval(mut vm, 'var first=document.getElementById("first"),order="",marker={},same=false;try{first.focus({get focusVisible(){order+="v";return true},get preventScroll(){order+="p";throw marker}})}catch(e){same=e===marker}first.tabIndex=4294967297;same&&order==="vp"&&first.tabIndex===1&&first.getAttribute("tabindex")==="1"')!.as_bool()
	assert focus_binding_eval(mut vm, 'var count=0;for(var run of [()=>HTMLElement.prototype.focus.call({}),()=>HTMLElement.prototype.blur.call({}),()=>document.hasFocus.call({}),()=>first.focus(true)])try{run()}catch(e){if(e instanceof TypeError)count++}count===4')!.as_bool()
}
