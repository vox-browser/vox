// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn factory_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-element-factories.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_namespaced_element_creation_uses_native_svg_nodes_case_and_prefixes() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert factory_eval(mut vm, 'var svg="http://www.w3.org/2000/svg",root=document.createElementNS(svg,"svg"),child=document.createElementNS(svg,"s:linearGradient");child.id="gradient";child.classList.add("native-svg");root.appendChild(child);document.body.appendChild(root);child instanceof Element&&child instanceof Node&&!(child instanceof HTMLElement)&&child.ownerDocument===document&&child.namespaceURI===svg&&child.prefix==="s"&&child.localName==="linearGradient"&&child.tagName==="s:linearGradient"&&document.getElementById("gradient")===child&&child.classList.contains("native-svg")&&Document.prototype.createElementNS.length===2')!.as_bool()
	native := document.get_element_by_id('gradient')?
	assert native.is_svg_element() && native.namespace_uri()? == 'http://www.w3.org/2000/svg'
	assert native.local_name() == 'linearGradient' && native.prefix()? == 's'
	assert factory_eval(mut vm, 'var xml=new Document(),e=xml.createElementNS("urn:test","x:Mixed");e.ownerDocument===xml&&e.namespaceURI==="urn:test"&&e.localName==="Mixed"&&e.prefix==="x"&&e.tagName==="x:Mixed"&&xml.createElement("Mixed").localName==="Mixed"&&document.createElement("DIV").localName==="div"&&document.createElementNS("", "plain").namespaceURI===null&&document.createElementNS(null,"plain").prefix===null')!.as_bool()
}

fn test_element_factory_argument_conversion_order_and_dictionary_union() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert factory_eval(mut vm, 'var log="",ns={toString(){log+="n";return "urn:test"}},name={toString(){log+="q";return "root"}},options={get customElementRegistry(){log+="r"},get is(){log+="i"}};var e=document.createElementNS(ns,name,options);log==="nqri"&&e.localName==="root"&&document.createElementNS(undefined,"plain").namespaceURI===null&&document.createElement("div",null) instanceof HTMLDivElement&&document.createElement("div",42) instanceof HTMLDivElement')!.as_bool()
	assert factory_eval(mut vm, 'var reason={},same=false,failed=false,thrower={toString(){throw reason}};try{document.createElementNS(thrower,"root")}catch(e){same=e===reason}try{document.createElementNS("urn:test",thrower)}catch(e){failed=e===reason}same&&failed')!.as_bool()
	assert factory_eval(mut vm, 'var count=0,argument={toString(){count++;throw reason}},caught=false;try{document.createElementNS(argument)}catch(e){caught=e instanceof TypeError}caught&&count===0')!.as_bool()
}

fn test_element_factory_native_validation_preserves_dom_exception_types_and_brands() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert factory_eval(mut vm, 'var invalid=0,ns=0;for(var run of [()=>document.createElementNS(null,"bad name"),()=>document.createElement("bad name")])try{run()}catch(e){if(e instanceof DOMException&&e.name==="InvalidCharacterError")invalid++}for(var run of [()=>document.createElementNS(null,"p:root"),()=>document.createElementNS("urn:wrong","xml:root"),()=>document.createElementNS("http://www.w3.org/2000/xmlns/","root")])try{run()}catch(e){if(e instanceof DOMException&&e.name==="NamespaceError")ns++}invalid===2&&ns===3')!.as_bool()
	assert factory_eval(mut vm, 'var n=0;for(var run of [()=>document.createElement(),()=>document.createElementNS(),()=>document.createElementNS(null),()=>Document.prototype.createElementNS.call({},null,"root"),()=>document.createElementNS(Symbol(),"root"),()=>document.createElement("div",Symbol()),()=>document.createElement("div",{customElementRegistry:{}})])try{run()}catch(e){if(e instanceof TypeError)n++}n===7')!.as_bool()
}

fn test_element_factory_options_construct_registered_builtins_and_use_scoped_registries() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert factory_eval(mut vm, 'var html="http://www.w3.org/1999/xhtml";class Button extends HTMLButtonElement{answer=42}customElements.define("x-factory-button",Button,{extends:"button"});var a=document.createElementNS(html,"button",{is:"x-factory-button"}),b=document.createElement("BUTTON",{is:"x-factory-button"}),legacy=document.createElement("button","x-factory-button");a instanceof Button&&b instanceof Button&&a.answer===42&&a.localName==="button"&&legacy instanceof HTMLButtonElement&&!(legacy instanceof Button)')!.as_bool()
	assert factory_eval(mut vm, 'var registry=new CustomElementRegistry();class Scoped extends HTMLElement{answer=43}registry.define("x-factory-scoped",Scoped);var e=document.createElementNS(html,"x-factory-scoped",{customElementRegistry:registry}),plain=document.createElementNS(html,"x-factory-scoped",{customElementRegistry:null});e instanceof Scoped&&e.answer===43&&!(plain instanceof Scoped)&&e.ownerDocument===document')!.as_bool()
	assert factory_eval(mut vm, 'var caught=false;try{document.createElementNS(html,"button",{is:"x-factory-button",customElementRegistry:null})}catch(e){caught=e instanceof DOMException&&e.name==="NotSupportedError"}caught')!.as_bool()
}

fn test_cached_namespaced_factory_executes_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-element-factory-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert factory_eval(mut vm, 'function make(){return document.createElementNS("http://www.w3.org/2000/svg","linearGradient").localName}make()==="linearGradient"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
