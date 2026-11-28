// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn tokens_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-token-list.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_class_list_native_identity_live_indices_value_forwarding_and_iteration() {
	mut document := html.parse_document('<body><div id="target" class="seed seed   second"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert tokens_eval(mut vm, 'var e=document.getElementById("target"),list=e.classList;list===e.classList&&list instanceof DOMTokenList&&!Array.isArray(list)&&list.length===2&&list[0]==="seed"&&list.item(1)==="second"&&list.item(2)===null&&list[2]===undefined&&list.value==="seed seed   second"&&String(list)===list.value&&Object.keys(list).join(",")==="0,1"&&Object.prototype.toString.call(list)==="[object DOMTokenList]"&&list[Symbol.iterator]===list.values')!.as_bool()
	assert tokens_eval(mut vm, 'e.className="one one two";var values="",keys="",entries="",third=true;for(var v of list)values+=v+",";for(var k of list.keys())keys+=k;for(var pair of list.entries())entries+=pair[0]+":"+pair[1]+",";list.forEach(function(v,k,o){third=third&&o===list&&this===e},e);third&&values==="one,two,"&&keys==="01"&&entries==="0:one,1:two,"&&list[0]==="one"')!.as_bool()
	assert tokens_eval(mut vm, 'e.classList="forwarded value";list===e.classList&&list.value==="forwarded value"&&list.length===2&&e.className==="forwarded value"')!.as_bool()
	native := document.get_element_by_id('target')?
	mut element := unsafe { &dom.Element(native) }
	element.set_attribute_value('class', 'native external')
	assert tokens_eval(mut vm, 'list[0]==="native"&&list.item(1)==="external"&&list.length===2')!.as_bool()
}

fn test_native_token_list_mutations_use_ordered_sets_and_live_selector_state() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body><div id="target" class="seed"></div></body>'), Hooks{})!
	defer { host.close() }
	assert tokens_eval(mut vm, 'var e=document.getElementById("target"),list=e.classList;list.add("added","seed","last")===undefined&&list.value==="seed added last"&&document.querySelector(".added")===e&&!list.contains("Added")&&list.remove("seed","missing")===undefined&&list.value==="added last"&&list.toggle("flag")&&list.contains("flag")&&!list.toggle("flag")&&!list.contains("flag")&&!list.toggle("flag",undefined)&&list.toggle("flag",1)&&list.replace("flag","added")&&list.value==="added last"&&!list.replace("missing","next")')!.as_bool()
	assert tokens_eval(mut vm, 'list.value="a a   b";list.add();list.value==="a b"&&list.remove()===undefined&&!list.contains("")&&!list.contains("bad token")')!.as_bool()
}

fn test_token_list_converts_all_arguments_before_native_validation_and_preserves_abrupt_values() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body><div id="target" class="seed"></div></body>'), Hooks{})!
	defer { host.close() }
	assert tokens_eval(mut vm, 'var list=document.getElementById("target").classList,log="",o={toString(){log+="s";return "next"}},syntax=false,invalid=false;try{list.add("",o)}catch(e){syntax=e instanceof DOMException&&e.name==="SyntaxError"}try{list.remove("seed","bad token")}catch(e){invalid=e instanceof DOMException&&e.name==="InvalidCharacterError"}syntax&&invalid&&log==="s"&&list.value==="seed"&&!list.contains("next")')!.as_bool()
	assert tokens_eval(mut vm, 'var reason={},same=false,thrower={toString(){throw reason}};try{list.add("good",thrower)}catch(e){same=e===reason}same&&list.value==="seed"')!.as_bool()
	assert tokens_eval(mut vm, 'var n=0;for(var run of [()=>DOMTokenList(),()=>new DOMTokenList(),()=>DOMTokenList.prototype.add.call({},thrower),()=>list.item(),()=>list.contains(),()=>list.replace("seed"),()=>list.toggle(),()=>list.supports("x"),()=>list.add(Symbol())])try{run()}catch(e){if(e instanceof TypeError)n++}n===9')!.as_bool()
}

fn test_token_list_mutations_publish_native_attribute_observer_records() {
	mut document := html.parse_document('<body><div id="target" class="seed"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	tokens_eval(mut vm, 'var e=document.getElementById("target"),records;var observer=new MutationObserver(function(list){records=list});observer.observe(e,{attributeOldValue:true});e.classList.add("added")')!
	assert tokens_eval(mut vm, 'records.length===1&&records[0].target===e&&records[0].attributeName==="class"&&records[0].oldValue==="seed"&&e.getAttribute("class")==="seed added"')!.as_bool()
	assert document.get_element_by_id('target')?.get_attribute_value('class') == 'seed added'
	assert tokens_eval(mut vm, r'var lone=document.createElement("div").classList;lone.add("\ud800");lone[0].charCodeAt(0)===55296&&lone.item(0).charCodeAt(0)===55296&&lone.value.charCodeAt(0)===55296&&lone.contains("\ud800")')!.as_bool()
}

fn test_cached_token_list_mutations_run_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-tokens-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert tokens_eval(mut vm, 'function alter(list){list.add("cached");return list.contains("cached")}alter(document.createElement("div").classList)')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
