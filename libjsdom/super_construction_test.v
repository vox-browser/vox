// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn native_super_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-super-spread.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_explicit_spread_super_constructs_native_targets_and_custom_elements_from_persisted_code() {
	directory := os.join_path(os.temp_dir(), 'vox-native-super-spread-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut expected := 0
	for visit in 0 .. 2 {
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		address := dom.URL{value: 'https://native-super.test/'}
		mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
		document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
		mut host := Host.create(vm, vm.realm(), document, Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert native_super_eval(mut vm, 'class Target extends EventTarget{constructor(...args){super(...args)}answer=42}class Box extends HTMLElement{constructor(...args){super(...args)}answer=43}customElements.define("x-spread-box",Box);var target=new Target(),box=document.createElement("x-spread-box"),seen=0;target.addEventListener("ping",function(e){if(e.target===target)seen++});target.dispatchEvent(new Event("ping"));target instanceof Target&&target instanceof EventTarget&&target.answer===42&&seen===1&&box instanceof Box&&box.localName==="x-spread-box"&&box.answer===43&&box.ownerDocument===document')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 0 { expected = stats.compiled_executables; assert expected >= 6 }
		else { assert stats.cache_hits == expected && stats.compiler_invocations == 0 && activity.entries >= u64(expected) }
		vm.close_native_code()!
		host.close()
	}
}
