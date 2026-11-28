// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import html
import libjs

fn style_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-style.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_libjs_element_style_is_same_object_and_uses_live_native_cssom() {
	mut document := html.parse_document('<body><div id="target" style="color:red"></div></body>')
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert style_eval(mut vm, 'var e=document.getElementById("target"),s=e.style;s===e.style&&s.color==="red"&&s.length===1&&s[0]==="color"&&s.item(1)===""&&s[1]===undefined&&s.parentRule===null')!.as_bool()
	assert style_eval(mut vm, 's.backgroundColor="blue";s.setProperty("width","12px","important");s.getPropertyValue("background-color")==="blue"&&s.getPropertyPriority("width")==="important"')!.as_bool()
	mut element := document.get_element_by_id('target')?
	assert css.element_style(element).get_property_value('background-color') == 'blue'
	assert element.get_attribute_value('style').contains('width: 12px !important;')
	element.set_attribute_value('style', 'height: 20px;')
	assert style_eval(mut vm, 's.height==="20px"&&s.color===""&&s.length===1&&s[0]==="height"')!.as_bool()
	assert style_eval(mut vm, 'e.style="color: green;float: left";s===e.style&&s.color==="green"&&s.cssFloat==="left"&&s.removeProperty("color")==="green"&&s.color===""')!.as_bool()
	assert style_eval(mut vm, 's.cssText="width: 10px; --x: 42;";s.setProperty("--x",null);s.getPropertyValue("--x")===""&&s.width==="10px"&&s.getPropertyPriority("width")===""')!.as_bool()
}

fn test_libjs_style_support_detection_and_brand_errors_use_native_property_metadata() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert style_eval(mut vm, 'var s=document.createElement("div").style;"animation" in s&&"transition" in s&&"backgroundColor" in s&&"background-color" in s&&!("fakeUnsupportedProperty" in s)&&s.animation===""')!.as_bool()
	assert style_eval(mut vm, 'var caught=false;try{s.setProperty.call({},"color","red")}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	assert style_eval(mut vm, 'var caught=false;try{s.setProperty("color")}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	assert style_eval(mut vm, 's.width="13px";s.width="invalid";s.setProperty("width","14px","invalid");s.width==="13px"&&Object.prototype.toString.call(s)==="[object CSSStyleProperties]"')!.as_bool()
}
