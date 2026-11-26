// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import platform
import os
import rand

fn test_select_and_options_indexed_assignment_share_the_live_option_owner() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option"),c=document.createElement("option");a.value="a";b.value="b";c.value="c";s[0]=a;var o=s.options;s[1]=b;o[0]=c;s.length===2&&s[0]===c&&s[1]===b&&o[0]===c&&a.parentNode===null&&s.item(0)===c&&s.selectedOptions[0]===c')!.as_bool()
}

fn test_indexed_option_assignment_fills_gaps_and_nullish_values_remove_options() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");s[2]=a;var o=s.options,ok=s.length===3&&o[2]===a&&o[0] instanceof HTMLOptionElement&&o[0].value==="";o[0]=null;ok=ok&&o.length===2&&o[1]===a;s[0]=undefined;ok&&o.length===1&&o[0]===a&&s[1]===undefined')!.as_bool()
}

fn test_indexed_option_replacement_inside_optgroup_keeps_native_parent() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),g=document.createElement("optgroup"),a=document.createElement("option"),b=document.createElement("option");g.appendChild(a);s.appendChild(g);s.options[0]=b;s[0]===b&&b.parentNode===g&&a.parentNode===null&&g.childNodes[0]===b')!.as_bool()
}

fn test_indexed_option_assignment_rejects_forged_interfaces_without_coercion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),o=s.options,reads=0,bad=0;for(var value of [1,"text",{},document.createElement("optgroup"),new Proxy(a,{}),{toString(){reads++;return "option"}}])try{o[0]=value}catch(e){if(e instanceof TypeError)bad++}bad===6&&reads===0&&o.length===0')!.as_bool()
}

fn test_indexed_define_property_invokes_native_setter_and_ignores_descriptor_flags() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option"),o=s.options;Object.defineProperty(o,"0",{value:a,writable:false,configurable:false,enumerable:false});o[1]=b;var d=Object.getOwnPropertyDescriptor(o,"0"),ok=d.writable&&d.configurable&&d.enumerable&&s[0]===a;Object.defineProperty(o,"0",{value:null});var reads=0;ok&&o[0]===b&&!Reflect.defineProperty(o,"0",{get(){reads++;return a}})&&Reflect.defineProperty(o,"9",{writable:true})&&o.length===1&&reads===0')!.as_bool()
}

fn test_indexed_setter_precedes_prototype_properties_and_respects_distinct_receiver() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),o=s.options,a=document.createElement("option"),original=Object.getPrototypeOf(o),intercepted=0;Object.setPrototypeOf(o,{set 0(x){intercepted++}});o[0]=a;Object.setPrototypeOf(o,original);var other={},ok=Reflect.set(o,"0",12,other)&&other[0]===12&&o[0]===a;var b=document.createElement("option"),proxy=new Proxy(o,{});proxy[0]=b;ok&&s[0]===b&&intercepted===0')!.as_bool()
}

fn test_select_legacy_index_descriptors_deletion_integrity_and_expandos() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");s[0]=a;var o=s.options,ok=true;for(var target of [s,o]){var d=Object.getOwnPropertyDescriptor(target,"0");ok=ok&&d.writable&&d.enumerable&&d.configurable&&!Reflect.deleteProperty(target,"0")&&!Reflect.preventExtensions(target)&&Object.isExtensible(target);target["01"]=7;ok=ok&&target["01"]===7&&target[0]===a&&Reflect.deleteProperty(target,"01")}s[0]=null;ok&&Reflect.deleteProperty(s,"0")&&Reflect.deleteProperty(o,"0")&&Object.keys(s).length===0')!.as_bool()
}

fn test_indexed_native_failure_preserves_completed_gap_insertions() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var outer=document.createElement("option"),s=document.createElement("select");outer.appendChild(s);var caught=false;try{s.options[2]=outer}catch(e){caught=e instanceof DOMException&&e.name==="HierarchyRequestError"}caught&&s.length===2&&s[0] instanceof HTMLOptionElement&&s[1] instanceof HTMLOptionElement&&outer.firstChild===s')!.as_bool()
}

fn test_indexed_select_services_survive_transient_arena_and_reject_closed_host() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('native select index services')
	entry := arena.enter()
	stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");s[1]=a;var o=s.options')!
	arena.leave(entry)
	for _, object in host.wrappers {
		if metadata := object.legacy_platform_object {
			if setter := metadata.indexed_setter {
				if setter is SelectElementIndices { assert !arena.contains(setter) }
			}
		}
	}
	arena.reset()
	assert stream_eval(mut vm, 's[1]===a&&o[1]===a&&s.length===2')!.as_bool()
	host.close()
	assert stream_eval(mut vm, 'var failed=false;try{o[0]=null}catch(e){failed=e instanceof TypeError}failed')!.as_bool()
}

fn test_native_cached_select_indices_use_current_owners_on_a_compiler_disabled_second_visit() {
	directory := os.join_path(os.temp_dir(), 'vox-indexed-revisit-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	source := 'function replaceAt(s,n,o){s[n]=o;return s.options[n]===o}var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option");var ok=replaceAt(s,1,a)&&replaceAt(s,0,b);s.options[0]=null;var d=Object.getOwnPropertyDescriptor(s,"0");ok&&s[0]===a&&s.length===1&&d.writable&&d.configurable&&!Reflect.deleteProperty(s,"0")'
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert stream_eval(mut vm, source)!.as_bool()
		before := vm.native_code_cache_stats()
		activity := vm.diagnose_native_code(false)!
		if visit == 0 { assert before.cache_misses > 0 && before.cache_hits == 0 }
		else {
			assert before.cache_hits > 0 && before.cache_misses == 0
			assert activity.entries > 0 && activity.fast_steps > 0 && activity.slow_steps > 0
		}
		after := vm.flush_native_code_cache()!
		assert after.compiler_invocations == u64(if visit == 0 { 1 } else { 0 })
		vm.close_native_code()!
		host.close()
	}
}
