// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

@[heap]
struct CustomElementObservations {
mut:
	errors []string
}

fn custom_elements_fixture() !(&Host, &libjs.VM, &dom.Document, &CustomElementObservations) {
	mut document := html.parse_document('<body><x-native id="existing" value="before"></x-native></body>')
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	seen := &CustomElementObservations{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{exception: fn [seen] (message string) {
		mut record := unsafe { &CustomElementObservations(seen) }; record.errors << message
	}})!
	return host, vm, document, seen
}

fn custom_elements_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'custom-elements.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_custom_registry_native_definitions_identity_scoping_and_brand_checks() {
	mut host, mut vm, document, seen := custom_elements_fixture()!
	defer { host.close() }
	assert custom_elements_eval(mut vm, 'class C extends HTMLElement{};customElements.define("x-empty",C);var scoped=new CustomElementRegistry();scoped.define("x-empty",C);customElements instanceof CustomElementRegistry&&scoped!==customElements&&customElements.get("x-empty")===C&&scoped.get("x-empty")===C&&customElements.getName(C)==="x-empty"&&customElements.get("missing")===undefined&&customElements.getName(function(){})===null&&Object.prototype.toString.call(scoped)==="[object CustomElementRegistry]"')!.as_bool()
	native := unsafe { &html.CustomElementRegistry(document.custom_element_registry()) }
	assert native.definition_count() == 1
	assert native.get_definition_with_name_and_local_name('x-empty', 'x-empty')?.constructor() != 0
	assert custom_elements_eval(mut vm, 'var n=0;for(var action of [()=>customElements.define("invalid",function(){}),()=>customElements.define("x-empty",function(){}),()=>customElements.define("x-other",C),()=>customElements.define("x-button",function(){},{extends:"missing"})])try{action()}catch(e){if(e instanceof DOMException)n++}var t=0;for(var action of [()=>CustomElementRegistry(),()=>customElements.get(),()=>customElements.define("x-arrow",()=>{}),()=>customElements.define("x-dict",function(){},7),()=>CustomElementRegistry.prototype.get.call({},"x-empty"),()=>Object.getOwnPropertyDescriptor(window,"customElements").get.call({})])try{action()}catch(e){if(e instanceof TypeError)t++}n===4&&t===6')!.as_bool()
	assert seen.errors.len == 0
}

fn test_custom_registry_metadata_conversion_reentrancy_and_original_exceptions() {
	mut host, mut vm, _, seen := custom_elements_fixture()!
	defer { host.close() }
	assert custom_elements_eval(mut vm, 'var marker={},order="",inner=false;function C(){};Object.defineProperty(C.prototype,"connectedCallback",{get(){order+="c";try{customElements.define("x-inner",function(){})}catch(e){inner=e instanceof DOMException&&e.name==="NotSupportedError"}return function(){}}});C.prototype.attributeChangedCallback=function(){};Object.defineProperty(C,"observedAttributes",{get(){order+="o";return [{toString(){order+="s";return "value"}}]}});Object.defineProperty(C,"disabledFeatures",{get(){order+="d";return []}});Object.defineProperty(C,"formAssociated",{get(){order+="f";return false}});customElements.define("x-meta",C);var caught=false;function Bad(){};Object.defineProperty(Bad.prototype,"connectedCallback",{get(){throw marker}});try{customElements.define("x-bad",Bad)}catch(e){caught=e===marker}customElements.define("x-bad",function(){});inner&&caught&&order==="cosdf"&&customElements.get("x-meta")===C')!.as_bool()
	assert seen.errors.len == 0
}

fn test_custom_element_upgrade_construction_identity_and_native_lifecycle_reactions() {
	mut host, mut vm, document, seen := custom_elements_fixture()!
	defer { host.close() }
	assert custom_elements_eval(mut vm, 'var old=document.getElementById("existing"),calls="",attr=false;class C extends HTMLElement{value=42;static get observedAttributes(){return ["value"]}constructor(){super();calls+="n"}connectedCallback(){calls+="c"}disconnectedCallback(){calls+="d"}attributeChangedCallback(name,oldValue,newValue,ns){calls+="a";attr=name==="value"&&oldValue===null&&newValue==="before"&&ns===null}};customElements.define("x-native",C);old===document.getElementById("existing")&&old instanceof C&&old.value===42&&calls==="nac"&&attr')!.as_bool()
	assert document.get_element_by_id('existing')?.custom_element_state_ == .custom
	assert custom_elements_eval(mut vm, 'var fresh=new C();fresh instanceof C&&fresh instanceof HTMLElement&&fresh.ownerDocument===document&&fresh.parentNode===null&&fresh.tagName==="X-NATIVE"&&fresh.value===42&&calls==="nacn"')!.as_bool()
	assert custom_elements_eval(mut vm, 'var created=document.createElement("x-native");document.body.appendChild(created);document.body.removeChild(created);created instanceof C&&calls==="nacnncd"')!.as_bool()
	assert custom_elements_eval(mut vm, 'C.prototype.connectedCallback=function(){throw new Error("replacement must not run")};document.body.appendChild(created);document.body.removeChild(created);calls==="nacnncdcd"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_when_defined_uses_real_promises_and_retains_original_rejections() {
	mut host, mut vm, _, seen := custom_elements_fixture()!
	defer { host.close() }
	assert custom_elements_eval(mut vm, 'var pending=customElements.whenDefined("x-later"),same=pending===customElements.whenDefined("x-later"),result=0,invalid=false,brand=false,original=false,marker={};pending.then(C=>{result=new C().value});customElements.whenDefined("invalid").catch(e=>{invalid=e instanceof DOMException&&e.name==="SyntaxError"});CustomElementRegistry.prototype.whenDefined.call({},"x-other").catch(e=>{brand=e instanceof TypeError});customElements.whenDefined({toString(){throw marker}}).catch(e=>{original=e===marker});class Later extends HTMLElement{value=42};customElements.define("x-later",Later);same&&pending instanceof Promise')!.as_bool()
	assert custom_elements_eval(mut vm, 'result===42&&invalid&&brand&&original&&customElements.whenDefined("x-later")!==customElements.whenDefined("x-later")')!.as_bool()
	assert seen.errors.len == 0
}

fn test_custom_element_failed_constructor_reports_and_close_removes_native_hook() {
	mut host, mut vm, mut document, seen := custom_elements_fixture()!
	assert custom_elements_eval(mut vm, 'class Bad extends HTMLElement{constructor(){super();throw new Error("constructor failure")}};customElements.define("x-native",Bad);document.getElementById("existing") instanceof Bad')!.as_bool()
	assert seen.errors.len == 1 && seen.errors[0].contains('constructor failure')
	native := document.get_element_by_id('existing')?
	// Match CustomElementAlgorithms.cpp: failed construction clears the
	// definition and pending reactions after the precustomized transition.
	assert native.custom_element_state_ == .precustomized
	assert native.custom_element_definition() == none && native.ensure_custom_element_reaction_queue().len == 0
	host.close()
	assert host.registries.len == 0
	document.invoke_custom_element_reactions()
	assert seen.errors.len == 1
}

fn test_cached_custom_element_constructor_and_callbacks_execute_without_compiler_on_revisit() {
	directory := os.join_path(os.temp_dir(), 'vox-libjs-custom-elements-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, _, seen := custom_elements_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert custom_elements_eval(mut vm, 'var calls=0;class C extends HTMLElement{value=42;connectedCallback(){calls++}};customElements.define("x-native",C);document.getElementById("existing").value===42&&calls===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		assert seen.errors.len == 0
		vm.close_native_code()!
		host.close()
	}
}
