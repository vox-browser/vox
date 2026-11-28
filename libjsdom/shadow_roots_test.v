// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn shadow_binding_fixture(markup string) !(&Host, &libjs.VM) {
	address := dom.URL{value:'https://shadow-binding.test/'}
	document := html.parse_navigation_document(markup, address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn shadow_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-shadow-bindings.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_shadow_wrappers_retain_native_identity_inheritance_closed_visibility_and_live_tree() {
	mut host, mut vm := shadow_binding_fixture('<body><div id="host"></div><div id="closed"></div></body>')!
	defer { host.close() }
	assert shadow_binding_eval(mut vm, 'var element=document.getElementById("host"),root=element.attachShadow({mode:"open",clonable:true,serializable:true,delegatesFocus:true,slotAssignment:"manual"});root.innerHTML="<span id=inside>shadow</span>";var child=root.querySelector("span"),closed=document.getElementById("closed"),hidden=closed.attachShadow({mode:"closed"});root===element.shadowRoot&&root.host===element&&root instanceof ShadowRoot&&root instanceof DocumentFragment&&root instanceof Node&&Object.getPrototypeOf(ShadowRoot)===DocumentFragment&&Object.prototype.toString.call(root)==="[object ShadowRoot]"&&root.mode==="open"&&root.clonable&&root.serializable&&root.delegatesFocus&&root.slotAssignment==="manual"&&child===root.getElementById("inside")&&child.getRootNode()===root&&child.getRootNode({composed:true})===document&&document.getElementById("inside")===null&&hidden.mode==="closed"&&hidden.host===closed&&closed.shadowRoot===null&&root.innerHTML==="<span id=\"inside\">shadow</span>"')!.as_bool()
}

fn test_attach_shadow_converts_dictionary_in_order_and_preserves_native_errors() {
	mut host, mut vm := shadow_binding_fixture('<body><div id="host"></div></body>')!
	defer { host.close() }
	assert shadow_binding_eval(mut vm, 'var element=document.getElementById("host"),order="",marker={},same=false;try{element.attachShadow({get clonable(){order+="c";return false},get customElementRegistry(){order+="r"},get delegatesFocus(){order+="d";return true},get mode(){order+="m";return "open"},get serializable(){order+="s";throw marker}})}catch(e){same=e===marker}var failures=0;for(var run of [()=>element.attachShadow(),()=>element.attachShadow({}),()=>element.attachShadow({mode:"bad"}),()=>element.attachShadow({mode:"open",slotAssignment:"bad"}),()=>Element.prototype.attachShadow.call({},{}),()=>new ShadowRoot()])try{run()}catch(e){if(e instanceof TypeError)failures++}same&&order==="crdms"&&element.shadowRoot===null&&failures===6')!.as_bool()
	assert shadow_binding_eval(mut vm, 'var root=element.attachShadow({mode:"open"}),failed=false;try{element.attachShadow({mode:"open"})}catch(e){failed=e instanceof DOMException&&e.name==="NotSupportedError"}failed&&element.shadowRoot===root')!.as_bool()
}

fn test_declarative_shadow_attachment_reuses_the_actual_root_and_clears_its_children() {
	mut host, mut vm := shadow_binding_fixture('<body><div id="host"><template shadowrootmode="open"><span>declarative</span></template></div></body>')!
	defer { host.close() }
	assert shadow_binding_eval(mut vm, 'var element=document.getElementById("host"),before=element.shadowRoot,child=before.firstChild,after=element.attachShadow({mode:"open"});before===after&&after.firstChild===null&&child.parentNode===null&&after.host===element')!.as_bool()
}

fn test_cached_shadow_attachment_uses_current_native_owners_without_a_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-shadow-cache-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := shadow_binding_fixture('<body><div id="host"></div></body>')!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert shadow_binding_eval(mut vm, 'var element=document.getElementById("host"),root=element.attachShadow({mode:"open"});root.innerHTML="<span>live</span>";root===element.shadowRoot&&root.host===element&&root.firstChild.textContent==="live"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && activity.entries > 0 }
		vm.close_native_code()!
		host.close()
	}
}
