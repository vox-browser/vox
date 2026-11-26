// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import os
import rand
import platform

fn test_html_collection_named_properties_follow_live_ids_and_names() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span"),b=document.createElement("span");a.id="first";a.setAttribute("name","alias");b.id="second";p.append(a,b);var c=p.children,d=Object.getOwnPropertyDescriptor(c,"first");var ok=c.first===a&&c.alias===a&&c.second===b&&!d.writable&&!d.enumerable&&d.configurable&&Object.keys(c).join()==="0,1"&&Reflect.ownKeys(c).join()==="0,1,first,alias,second";a.id="renamed";ok&&c.first===undefined&&c.renamed===a')!.as_bool()
}

fn test_collection_prototype_names_hide_native_names_without_override_builtins() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span"),b=document.createElement("span");a.id="length";b.id="item";p.append(a,b);var c=p.children;c.length===2&&typeof c.item==="function"&&c.namedItem("length")===a&&c.namedItem("item")===b&&Object.getOwnPropertyDescriptor(c,"length")===undefined&&!Reflect.ownKeys(c).includes("length")&&!Reflect.defineProperty(c,"length",{value:9})')!.as_bool()
}

fn test_collection_owned_expandos_hide_later_native_names_until_deleted() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),c=p.children;c.extra=7;var a=document.createElement("span");a.id="extra";p.appendChild(a);var ok=c.extra===7&&Reflect.defineProperty(c,"extra",{value:8})&&c.extra===8&&Reflect.deleteProperty(c,"extra");ok&&c.extra===a&&!Reflect.deleteProperty(c,"extra")&&Object.keys(c).join()==="0"')!.as_bool()
}

fn test_collection_named_visibility_preserves_proxy_exceptions() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span");a.id="field";p.appendChild(a);var c=p.children,marker={},caught=0;Object.setPrototypeOf(c,new Proxy({}, {getOwnPropertyDescriptor(){throw marker}}));for(var call of [()=>c.field,()=>Reflect.ownKeys(c),()=>Reflect.deleteProperty(c,"field")])try{call()}catch(e){if(e===marker)caught++}caught===3&&Object.getOwnPropertyDescriptor(c,"0").value===a')!.as_bool()
}

fn test_collection_named_visibility_observes_dom_mutation_during_proxy_traps() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span");a.id="old";p.appendChild(a);var c=p.children;Object.setPrototypeOf(c,new Proxy({}, {getOwnPropertyDescriptor(t,k){if(k==="old")a.id="new";return undefined},getPrototypeOf(){return null}}));var discarded=c.old;c.new===a&&Reflect.ownKeys(c).includes("new")&&!Reflect.ownKeys(c).includes("old")')!.as_bool()
}

fn test_select_option_named_views_track_selectedness_without_named_select_properties() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");s.multiple=true;a.id="choice";a.setAttribute("name","alias");s.appendChild(a);a.selected=true;var c=s.selectedOptions,o=s.options,ok=o.choice===a&&o.alias===a&&c.choice===a&&s.choice===undefined;a.selected=false;ok&&c.choice===undefined&&o.choice===a&&Reflect.ownKeys(o).includes("choice")&&!Reflect.ownKeys(c).includes("choice")')!.as_bool()
}

fn test_form_named_and_indexed_properties_share_lazy_external_control_owners() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),outside=document.createElement("input"),a=document.createElement("input"),b=document.createElement("input");f.id="owner";outside.name="outside";outside.setAttribute("form","owner");a.id="field";a.name=b.name="group";f.append(a,b);document.body.append(outside,f);var r=f.group,c=f.elements;f[0]===outside&&f[1]===a&&f.outside===outside&&f.field===a&&r instanceof RadioNodeList&&r.length===2&&c.group instanceof RadioNodeList&&c.field===a&&f.length===3&&!Reflect.deleteProperty(f,"0")&&!Reflect.defineProperty(f,"0",{value:b})&&!Object.getOwnPropertyDescriptor(f,"field").enumerable')!.as_bool()
}

fn test_form_named_properties_override_builtins_while_setters_keep_idl_behavior() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input"),c=document.createElement("input");a.name="action";b.name="elements";c.name="submit";f.append(a,b,c);document.body.appendChild(f);var getter=Object.getOwnPropertyDescriptor(HTMLFormElement.prototype,"elements").get;f.action="/changed";f.action===a&&f.elements===b&&f.submit===c&&f.getAttribute("action")==="/changed"&&getter.call(f).length===3&&!Reflect.deleteProperty(f,"action")&&!Reflect.defineProperty(f,"action",{value:7})')!.as_bool()
}

fn test_form_past_names_survive_rename_but_leave_with_the_control_owner() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),g=document.createElement("form"),a=document.createElement("input");f.id="f";g.id="g";a.name="before";f.appendChild(a);document.body.append(f,g);var ok=f.before===a;a.name="after";ok=ok&&f.before===a&&f.after===a;a.setAttribute("form","g");ok&&f.before===undefined&&f.after===undefined&&g.after===a')!.as_bool()
}

fn test_form_array_indices_do_not_fall_through_to_native_named_properties() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input");a.name="9";b.name="4294967295";f.append(a,b);document.body.appendChild(f);f[0]===a&&f[9]===undefined&&f.elements.namedItem("9")===a&&f["4294967295"]===b')!.as_bool()
}

fn test_saved_form_and_radio_views_follow_insertion_and_removal_with_external_controls() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input"),outside=document.createElement("input");f.id="root-owner";a.name=b.name=outside.name="g";outside.setAttribute("form",f.id);f.append(a,b);var c=f.elements,r=c.g;document.body.append(outside,f);var ok=c===f.elements&&c.length===3&&r.length===3&&r[0]===outside&&NodeList.prototype.item.call(r,0)===outside;document.body.removeChild(f);ok&&c.length===2&&r.length===2&&r[0]===a')!.as_bool()
}

fn test_collection_and_nodelist_item_conversion_observes_form_root_moves() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input"),outside=document.createElement("input");f.id="coercion-owner";a.name=b.name=outside.name="g";outside.setAttribute("form",f.id);f.append(a,b);document.body.appendChild(outside);var c=f.elements,r=c.g;var selected=r.item({valueOf(){document.body.appendChild(f);return 0}});document.body.removeChild(f);var selectedAgain=c.item({valueOf(){document.body.appendChild(f);return 0}});selected===outside&&selectedAgain===outside&&r.length===3')!.as_bool()
}

fn test_named_collection_records_survive_transient_arena_reset() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('named collection properties')
	entry := arena.enter()
	stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input");a.name="field";f.appendChild(a);document.body.appendChild(f);var c=f.elements;f.field===a&&c.field===a')!
	arena.leave(entry)
	for _, object in host.wrappers {
		if metadata := object.legacy_platform_object {
			if native := metadata.named_properties { if native is FormElementProperties { assert !arena.contains(native) } }
		}
	}
	arena.reset()
	assert stream_eval(mut vm, 'f.field===a&&c.field===a&&f[0]===a')!.as_bool()
}

fn test_native_cached_named_collection_access_uses_live_owners_on_compiler_disabled_revisit() {
	directory := os.join_path(os.temp_dir(), 'vox-named-revisit-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	source := 'function lookup(c,k){return c[k]}var p=document.createElement("div"),a=document.createElement("span");a.id="before";p.appendChild(a);var c=p.children,ok=lookup(c,"before")===a;a.id="after";ok&&lookup(c,"before")===undefined&&lookup(c,"after")===a'
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert stream_eval(mut vm, source)!.as_bool()
		before := vm.native_code_cache_stats(); activity := vm.diagnose_native_code(false)!
		if visit == 0 { assert before.cache_misses > 0 && before.cache_hits == 0 }
		else { assert before.cache_hits > 0 && before.cache_misses == 0 && activity.entries > 0 && activity.fast_steps > 0 && activity.slow_steps > 0 }
		after := vm.flush_native_code_cache()!
		assert after.compiler_invocations == u64(if visit == 0 { 1 } else { 0 })
		vm.close_native_code()!; host.close()
	}
}
