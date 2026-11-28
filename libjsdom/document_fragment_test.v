// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn fragment_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'document-fragment.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 10000}) or { return error(exception_message(err)) }
}

fn test_document_fragment_native_constructor_subclass_and_owner_identity() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert fragment_eval(mut vm, 'class F extends DocumentFragment{value=42}var f=new F();f instanceof F&&f instanceof DocumentFragment&&f instanceof Node&&f.ownerDocument===document&&f.nodeType===11&&f.nodeName==="#document-fragment"&&f.parentNode===null&&f.value===42&&Object.getPrototypeOf(DocumentFragment)===Node&&Object.getPrototypeOf(DocumentFragment.prototype)===Node.prototype&&Object.prototype.toString.call(f)==="[object DocumentFragment]"')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('f'))!
	native := host.nodes[voidptr(value.as_object())] or { panic('Missing native fragment') }
	assert native.is_document_fragment() && voidptr(native.document()) == voidptr(document)
}

fn test_document_fragment_factory_mutations_transfer_actual_children_and_keep_wrappers() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert fragment_eval(mut vm, 'var f=document.createDocumentFragment(),e=document.createElement("div");e.id="moved";f.appendChild(e);var before=f.querySelector("#moved"),same=f.getElementById("moved")===e;document.body.appendChild(f);same&&before===e&&e.parentNode===document.body&&document.getElementById("moved")===e&&f.querySelector("#moved")===null&&f.getElementById("moved")===null&&f.parentNode===null&&f instanceof DocumentFragment')!.as_bool()
	assert document.get_element_by_id('moved')?.as_node().parent()?.is_element()
}

fn test_document_fragment_factory_uses_receiver_document_and_checks_brands() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert fragment_eval(mut vm, 'var xml=new Document(),f=xml.createDocumentFragment(),n=0;for(var action of [()=>DocumentFragment(),()=>Document.prototype.createDocumentFragment.call({}),()=>Document.prototype.createDocumentFragment.call(f),()=>DocumentFragment.prototype.querySelector.call({},"div")])try{action()}catch(e){if(e instanceof TypeError)n++}f.ownerDocument===xml&&f instanceof DocumentFragment&&n===4')!.as_bool()
	assert fragment_eval(mut vm, 'var invalid=false;try{f.querySelector("[")}catch(e){invalid=e instanceof DOMException&&e.name==="SyntaxError"}invalid')!.as_bool()
}
