// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn interface_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-interfaces.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 10000}) or { return error(exception_message(err)) }
}

fn test_node_element_and_document_interface_objects_use_native_wrapper_identity() {
	mut document := html.parse_document('<body><div id="target"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert interface_eval(mut vm, 'var e=document.getElementById("target");e instanceof HTMLElement&&e instanceof Element&&e instanceof Node&&document instanceof Document&&document instanceof Node&&Object.getPrototypeOf(e)===HTMLDivElement.prototype&&Object.getPrototypeOf(HTMLDivElement.prototype)===HTMLElement.prototype&&Object.getPrototypeOf(HTMLElement.prototype)===Element.prototype&&Object.getPrototypeOf(Element.prototype)===Node.prototype&&Object.getPrototypeOf(Document.prototype)===Node.prototype&&Object.getPrototypeOf(Element)===Node&&Object.getPrototypeOf(Document)===Node&&Object.getPrototypeOf(HTMLElement)===Element&&e.constructor===HTMLDivElement&&document.constructor===Document')!.as_bool()
	assert interface_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(Node,"ELEMENT_NODE");Node.ELEMENT_NODE===1&&Node.prototype.DOCUMENT_NODE===9&&Element.DOCUMENT_POSITION_CONTAINS===8&&d.enumerable&&!d.writable&&!d.configurable&&Element.length===0&&Object.prototype.toString.call(e)==="[object HTMLDivElement]"')!.as_bool()
	for source in ['Node()', 'new Node()', 'Element()', 'new Element()', 'Document()', 'HTMLElement()', 'new HTMLElement()'] {
		assert interface_eval(mut vm, 'var caught=false;try{'+source+'}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	}
}

fn test_document_constructor_creates_independent_native_xml_document_and_supports_subclasses() {
	mut document := html.parse_document('<body><div id="main"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert interface_eval(mut vm, 'class D extends Document{value=42}var d=new D(),e=d.createElement("root");d instanceof D&&d instanceof Document&&d instanceof Node&&d.value===42&&d.URL==="about:blank"&&d.nodeType===9&&d.ownerDocument===null&&d.body===null&&d.documentElement===null&&e.ownerDocument===d&&e instanceof Element&&!(e instanceof HTMLElement)&&d.getElementById("main")===null&&document.getElementById("main")!==null')!.as_bool()
	assert host.owned_documents.len == 1
	native := host.owned_documents[0]
	assert native.document_type() == dom.DocumentType_.xml
	assert voidptr(native) != voidptr(document)
	host.close()
	assert native.has_been_destroyed() && host.owned_documents.len == 0
}
