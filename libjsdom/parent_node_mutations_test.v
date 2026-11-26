// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs

fn parent_mutation_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'parent-node-mutations.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_parent_variadic_mutations_move_native_nodes_in_argument_order() {
	mut document := html.parse_document('<body><i id="a">A</i><i id="b">B</i><i id="c">C</i></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert parent_mutation_eval(mut vm, 'var a=document.getElementById("a"),b=document.getElementById("b"),body=document.body;var result=body.append(b,a,b);body.textContent==="CAB"&&result===undefined&&document.getElementById("a")===a')!.as_bool()
	assert parent_mutation_eval(mut vm, 'body.prepend("start",b);body.textContent==="startBCA"&&b.parentNode===body')!.as_bool()
	assert parent_mutation_eval(mut vm, 'body.replaceChildren(a,"tail");body.textContent==="Atail"&&a.parentNode===body&&b.parentNode===null&&document.getElementById("b")===null')!.as_bool()
	assert parent_mutation_eval(mut vm, 'body.append();body.prepend();body.textContent==="Atail"')!.as_bool()
	assert parent_mutation_eval(mut vm, 'body.replaceChildren();body.textContent===""&&a.parentNode===null')!.as_bool()
}

fn test_parent_variadic_conversion_precedes_mutation_and_preserves_original_errors() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body><i id="a">A</i></body>'), Hooks{})!
	defer { host.close() }
	assert parent_mutation_eval(mut vm, 'var marker={},order="",a=document.getElementById("a"),f=new DocumentFragment(),caught=false;try{f.append(a,{toString(){order+="x";return "first"}},{toString(){order+="y";throw marker}})}catch(e){caught=e===marker}caught&&order==="xy"&&a.parentNode===document.body&&f.textContent===""')!.as_bool()
	assert parent_mutation_eval(mut vm, 'var n=0;for(var call of [()=>Element.prototype.append.call({},"x"),()=>document.body.append(Symbol()),()=>document.body.append(document)])try{call()}catch(e){if(e instanceof TypeError||e instanceof DOMException&&e.name==="HierarchyRequestError")n++}n===3')!.as_bool()
}

fn test_parent_mutations_work_for_native_fragments_documents_and_custom_reactions() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert parent_mutation_eval(mut vm, 'var f=new DocumentFragment(),e=document.createElement("span");e.id="inside";f.append("text",e);f.prepend("before");f.textContent==="beforetext"&&f.getElementById("inside")===e')!.as_bool()
	assert parent_mutation_eval(mut vm, 'var d=new Document(),root=d.createElement("root");d.append(root);d.documentElement===root&&root.ownerDocument===d')!.as_bool()
	assert parent_mutation_eval(mut vm, 'var calls=0;class C extends HTMLElement{connectedCallback(){calls++}disconnectedCallback(){calls--}}customElements.define("x-parent",C);var e=new C();document.body.append(e);var connected=calls===1;document.body.replaceChildren();connected&&calls===0&&e.parentNode===null')!.as_bool()
}
