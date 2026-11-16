// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import html
import libjs

fn computed_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document_with_url('<body><div id="target" style="display:block;position:relative;color:red;--answer:42"></div></body>', dom.URL{ value: 'https://computed-style.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'computed-style')!
	_ = css.css_style_computer_for(document)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn computed_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-computed-style.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_computed_styles_are_live_native_declarations_separate_from_inline_style() {
	mut host, mut vm := computed_binding_fixture()!
	defer { host.close() }
	assert computed_binding_eval(mut vm, 'var e=document.getElementById("target"),s=getComputedStyle(e);s!==e.style&&s!==getComputedStyle(e)&&s.display==="block"&&s.position==="relative"&&s.getPropertyValue("--answer")==="42"&&s.parentRule===null&&s.length>0&&s[0]===s.item(0)&&Object.prototype.toString.call(s)==="[object CSSStyleProperties]"')!.as_bool()
	assert computed_binding_eval(mut vm, 'e.style.position="absolute";s.position==="absolute"&&s.getPropertyPriority("position")===""')!.as_bool()
	assert computed_binding_eval(mut vm, 'var caught=0;for(var run of [()=>s.setProperty("display","none"),()=>s.removeProperty("color"),()=>{s.position="fixed"},()=>{s.cssText="color:blue"}])try{run()}catch(error){if(error instanceof DOMException&&error.name==="NoModificationAllowedError")caught++}caught===4&&e.style.display==="block"')!.as_bool()
}

fn test_computed_style_validates_window_element_and_original_pseudo_conversion() {
	mut host, mut vm := computed_binding_fixture()!
	defer { host.close() }
	assert computed_binding_eval(mut vm, 'var e=document.getElementById("target"),marker={},same=false;try{getComputedStyle(e,{toString(){throw marker}})}catch(error){same=error===marker}var count=0;for(var run of [()=>getComputedStyle(),()=>getComputedStyle({}),()=>getComputedStyle(document),()=>getComputedStyle.call({},e)])try{run()}catch(error){if(error instanceof TypeError)count++}same&&count===4')!.as_bool()
}
