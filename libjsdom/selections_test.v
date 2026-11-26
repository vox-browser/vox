// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import html
import dom

fn selection_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document_with_url('<body><button id="button">button</button></body>', dom.URL{ value: 'https://selections.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'selection_binding')!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn selection_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'selections.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_document_selection_wraps_native_range_identity_direction_and_utf16_offsets() {
	mut host, mut vm := selection_binding_fixture()!
	defer { host.close() }
	assert selection_binding_eval(mut vm, 'var s=getSelection(),node=document.createTextNode("a😀bc");document.body.appendChild(node);s instanceof Selection&&s===window.getSelection()&&s===document.getSelection()&&s.rangeCount===0&&s.anchorNode===null&&s.type==="None"&&String(s)===""')!.as_bool()
	assert selection_binding_eval(mut vm, 's.setBaseAndExtent(node,4,node,1);s.anchorNode===node&&s.anchorOffset===4&&s.focusNode===node&&s.focusOffset===1&&s.rangeCount===1&&!s.isCollapsed&&s.type==="Range"&&s.direction==="backward"&&String(s)==="😀b"&&s.containsNode(node,true)')!.as_bool()
	assert selection_binding_eval(mut vm, 's.collapseToStart();var valid=s.isCollapsed&&s.anchorOffset===1&&s.type==="Caret";s.extend(node,3);valid&&String(s)==="😀"&&s.focusOffset===3')!.as_bool()
	assert selection_binding_eval(mut vm, 's.removeAllRanges();s.rangeCount===0&&s.anchorNode===null&&s.focusNode===null&&s.isCollapsed&&String(s)===""')!.as_bool()
}

fn test_selection_mutations_reach_the_document_and_preserve_native_dom_exceptions() {
	mut host, mut vm := selection_binding_fixture()!
	defer { host.close() }
	assert selection_binding_eval(mut vm, 'var s=getSelection(),node=document.createTextNode("abcd");document.body.appendChild(node);s.collapse(node,1);s.extend(node,3);s.deleteFromDocument();node.data==="ad"&&s.isCollapsed')!.as_bool()
	assert selection_binding_eval(mut vm, 'var count=0;for(var run of [()=>new Selection(),()=>Selection.prototype.collapse.call({},node),()=>s.selectAllChildren({})])try{run()}catch(e){if(e instanceof TypeError)count++}var bounds=false;try{s.collapse(node,99)}catch(e){bounds=e instanceof DOMException&&e.name==="IndexSizeError"}count===3&&bounds')!.as_bool()
	assert selection_binding_eval(mut vm, 's.empty();var failed=false;try{s.collapseToEnd()}catch(e){failed=e instanceof DOMException&&e.name==="InvalidStateError"}var detached=document.implementation.createHTMLDocument("detached");failed&&detached.getSelection()===null')!.as_bool()
}
