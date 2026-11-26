// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn template_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-template-content.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_template_contents_use_actual_native_fragments_and_shared_inert_owner_documents() {
	mut document := html.parse_document('<body><template id="t"><span id="inside">hello</span></template><template id="other"></template></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert template_eval(mut vm, 'var t=document.getElementById("t"),content=t.content,other=document.getElementById("other");t instanceof HTMLTemplateElement&&content instanceof DocumentFragment&&content===t.content&&content.ownerDocument!==document&&content.ownerDocument===other.content.ownerDocument&&content.childNodes.length===1&&t.childNodes.length===0&&t.textContent===""&&content.textContent==="hello"&&content.querySelector("span").id==="inside"&&document.getElementById("inside")===null')!.as_bool()
	template := unsafe { &dom.HTMLTemplateElement(document.get_element_by_id('t')?) }
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('content'))!
	bound := host.nodes[voidptr(value.as_object())] or { panic('Missing template fragment wrapper') }
	assert voidptr(bound) == voidptr(template.content().as_node())
	assert voidptr(bound.document()) != voidptr(document)
}

fn test_template_inner_html_keeps_fragment_identity_and_insertion_adopts_native_children() {
	mut document := html.parse_document('<body><template id="t"></template></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert template_eval(mut vm, 'var t=document.getElementById("t"),content=t.content,list=content.childNodes;t.innerHTML="<b id=inside>value</b>";var child=content.getElementById("inside"),owner=content.ownerDocument;content===t.content&&list.length===1&&child.ownerDocument===owner&&content.querySelector("b")===child&&t.childNodes.length===0&&document.getElementById("inside")===null')!.as_bool()
	assert template_eval(mut vm, 'document.body.appendChild(content);content===t.content&&content.childNodes.length===0&&list.length===0&&child.ownerDocument===document&&child.parentNode===document.body&&document.getElementById("inside")===child&&content.ownerDocument===owner')!.as_bool()
	assert template_eval(mut vm, 'var xml=new Document();xml.appendChild(t);t.ownerDocument===xml&&t.content===content&&content.ownerDocument!==owner&&content.ownerDocument!==document')!.as_bool()
}

fn test_template_content_getter_checks_native_brand_and_is_readonly() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert template_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(HTMLTemplateElement.prototype,"content"),get=d.get,div=document.createElement("div"),svg=document.createElementNS("http://www.w3.org/2000/svg","template"),n=0;Object.setPrototypeOf(div,HTMLTemplateElement.prototype);for(var receiver of [{},div,document,svg])try{get.call(receiver)}catch(e){if(e instanceof TypeError)n++}var t=document.createElement("template"),content=t.content;t.content={};n===4&&t.content===content&&d.set===undefined&&d.enumerable&&d.configurable')!.as_bool()
}

fn test_cached_template_content_access_and_mutation_work_in_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-template-content-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert template_eval(mut vm, 'function fill(t){t.content.append(document.createElement("span"));return t.content.childNodes.length}fill(document.createElement("template"))===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
