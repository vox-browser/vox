// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs

fn selector_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-element-selectors.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_element_matches_and_closest_use_native_checked_selectors_and_wrapper_identity() {
	mut document := html.parse_document('<body><section id="outer" class="scope"><div class="container"><span id="child" data-value="yes"></span></div></section></body>')
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert selector_eval(mut vm, 'var c=document.getElementById("child"),outer=document.getElementById("outer");c.matches("section.scope > .container > span[data-value=yes]")&&!c.matches("section")&&c.closest(".scope")===outer&&c.closest("#child")===c&&c.closest(":scope")===c&&c.closest("article")===null')!.as_bool()
	assert selector_eval(mut vm, 'var n=0;for(var run of [()=>c.matches("["),()=>c.closest("[")])try{run()}catch(e){if(e instanceof DOMException&&e.name==="SyntaxError")n++}n===2')!.as_bool()
}

fn test_toggle_attribute_uses_native_mutation_and_attribute_names_are_fresh_arrays() {
	mut document := html.parse_document('<body><div id="target"></div></body>')
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert selector_eval(mut vm, 'var e=document.getElementById("target"),names=e.getAttributeNames(),observer=new MutationObserver(()=>{});observer.observe(e,{attributes:true});e.toggleAttribute("hidden")&&e.hasAttribute("hidden")&&!e.toggleAttribute("hidden")&&!e.hasAttribute("hidden")&&!e.toggleAttribute("hidden",false)&&e.toggleAttribute("hidden",true)&&!e.toggleAttribute("hidden",undefined)&&names.length===1&&names[0]==="id"&&e.getAttributeNames()!==names&&observer.takeRecords().length===4')!.as_bool()
}
