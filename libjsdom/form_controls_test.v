// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import platform
import rand

fn test_native_input_live_value_and_default_attribute_stay_distinct() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input");e.defaultValue="server";var initial=e.value;e.value="edited";e.defaultValue="next";initial==="server"&&e.value==="edited"&&e.defaultValue==="next"&&e.getAttribute("value")==="next"&&!Object.prototype.hasOwnProperty.call(e,"value")')!.as_bool()
	object := vm.global_object().get(mut vm, libjs.PropertyName.from_str('e'))!.as_object()
	node := host.nodes[voidptr(object)] or { panic('Missing native input') }
	input := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(node) })
	assert input.value() == 'edited'
}

fn test_native_text_control_null_conversion_newlines_and_utf16_values() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var i=document.createElement("input"),t=document.createElement("textarea");i.value=null;t.value=null;var empty=i.value===""&&t.value==="";i.value=undefined;t.value=undefined;var undef=i.value==="undefined"&&t.value==="undefined";i.value="a\r\nb";t.value="a\r\nb\rc";var lines=i.value==="ab"&&t.value==="a\nb\nc";i.value="\ud800😀\udc00";t.value=i.value;empty&&undef&&lines&&i.value.length===4&&t.textLength===4&&i.value.charCodeAt(0)===55296&&t.value.charCodeAt(3)===56320')!.as_bool()
}

fn test_native_checkedness_radio_groups_and_default_checked_use_actual_state() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form><input id=a type=radio name=g checked><input id=b type=radio name=g></form>";var a=document.getElementById("a"),b=document.getElementById("b");b.checked=true;var group=!a.checked&&b.checked&&a.defaultChecked&&!b.defaultChecked;b.defaultChecked=true;b.checked=false;b.defaultChecked=false;b.defaultChecked=true;a.indeterminate=true;group&&!b.checked&&b.defaultChecked&&a.indeterminate&&!a.hasAttribute("indeterminate")')!.as_bool()
}

fn test_native_form_data_reads_script_control_changes_and_explicit_empty_checkbox_value() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input id=text name=text value=before><input id=check name=check type=checkbox checked><textarea id=area name=area>before</textarea><input id=skip name=skip value=x></form>";var form=document.getElementById("f"),text=document.getElementById("text"),check=document.getElementById("check"),area=document.getElementById("area"),skip=document.getElementById("skip");text.value="after";check.value="";area.value="edited";skip.disabled=true;var data=new FormData(form);data.get("text")==="after"&&data.get("check")===""&&data.get("area")==="edited"&&!data.has("skip")&&text.getAttribute("value")==="before"&&area.defaultValue==="before"&&check.value===""')!.as_bool()
}

fn test_native_select_initialization_value_and_no_selection_are_observable_by_form_data() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><select id=s name=s><option disabled value=x>X</option><option value=a>A</option><option value=b>B</option></select></form>";var form=document.getElementById("f"),s=document.getElementById("s"),initial=new FormData(form).get("s");s.value="b";var changed=s.selectedIndex===2&&new FormData(form).get("s")==="b";s.selectedIndex=-1;var cleared=s.value===""&&s.selectedIndex===-1&&!new FormData(form).has("s");s.value="missing";initial==="a"&&changed&&cleared&&s.selectedIndex===-1&&s.value===""&&s.type==="select-one"')!.as_bool()
}

fn test_native_option_selectedness_and_multiple_select_keep_attribute_defaults() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><select id=s name=s multiple><option id=a value=a selected>A</option><option id=b value=b>B</option></select></form>";var s=document.getElementById("s"),a=document.getElementById("a"),b=document.getElementById("b");b.selected=true;a.selected=false;var multi=s.type==="select-multiple"&&a.defaultSelected&&!a.selected&&b.selected&&!b.defaultSelected&&new FormData(document.getElementById("f")).getAll("s").join()==="b";s.multiple=false;a.selected=true;multi&&s.value==="a"&&s.selectedIndex===0&&!b.selected&&b.index===1')!.as_bool()
}

fn test_native_option_text_label_and_value_follow_native_algorithms() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var o=document.createElement("option");o.text="  A  label \n ";var initial=o.text==="A label"&&o.value==="A label"&&o.label==="A label";o.value="";o.label="shown";initial&&o.value===""&&o.text==="A label"&&o.label==="shown"&&o.getAttribute("value")===""')!.as_bool()
}

fn test_native_control_form_owner_is_live_and_wrapper_identity_is_preserved() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=a><input id=i><button id=b>Go</button></form><form id=c></form><textarea id=t form=a></textarea>";var a=document.getElementById("a"),c=document.getElementById("c"),i=document.getElementById("i"),b=document.getElementById("b"),t=document.getElementById("t");var initial=i.form===a&&b.form===a&&t.form===a;i.setAttribute("form","c");a.id="renamed";initial&&i.form===c&&b.form===a&&t.form===null')!.as_bool()
}

fn test_native_control_attribute_reflection_and_type_specific_value_sanitization() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var i=document.createElement("input"),b=document.createElement("button");i.type="NUMBER";i.value="bad";i.name="field";i.required={};i.disabled=0;b.type="bad";b.value=null;var normal=i.type==="number"&&i.value===""&&i.getAttribute("name")==="field"&&i.required&&i.hasAttribute("required")&&!i.disabled&&b.type==="submit"&&b.value==="null";i.type="file";var invalid=false;try{i.value="path"}catch(e){invalid=e instanceof DOMException&&e.name==="InvalidStateError"}i.value="";normal&&invalid&&i.value===""')!.as_bool()
}

fn test_native_control_receiver_checks_precede_author_conversion_and_preserve_throws() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,"value"),i=document.createElement("input"),reads=0,bad=0;for(var receiver of [{},document.createElement("button"),new Proxy(i,{})])try{d.set.call(receiver,{toString(){reads++;return "x"}})}catch(e){if(e instanceof TypeError)bad++}var marker={},same=false;try{i.value={toString(){throw marker}}}catch(e){same=e===marker}bad===3&&reads===0&&same&&d.enumerable&&d.configurable&&typeof d.get==="function"&&typeof d.set==="function"')!.as_bool()
}

fn test_native_control_custom_element_reactions_observe_reflected_attribute_setters() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var seen=[];class NativeField extends HTMLInputElement{static get observedAttributes(){return ["name","disabled","value"]}attributeChangedCallback(n,o,v){seen.push([n,o,v])}}customElements.define("native-field",NativeField,{extends:"input"});var e=document.createElement("input",{is:"native-field"});e.name="field";e.disabled=true;e.defaultValue="server";e.value="edited";e instanceof NativeField&&seen.length===3&&seen[0].join() === "name,,field"&&seen[1][0]==="disabled"&&seen[2][2]==="server"&&e.value==="edited"')!.as_bool()
}

fn test_native_control_mutations_notify_host_without_input_or_change_events() {
	address := dom.URL{value: 'https://native-controls.test/'}
	mut document := html.parse_navigation_document('<body><input id=i></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut changes := []int{len: 1}
	mut host := Host.create(vm, vm.realm(), document, Hooks{changed: fn [mut changes] () { changes[0]++ }})!
	defer { host.close() }
	assert stream_eval(mut vm, 'var events=0,i=document.getElementById("i");i.addEventListener("input",()=>events++);i.addEventListener("change",()=>events++);i.value="new";i.type="checkbox";i.checked=true;i.disabled=true;events===0')!.as_bool()
	assert changes[0] >= 4
}

fn test_native_control_models_survive_transient_arena_reset() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('native form control models')
	entry := arena.enter()
	stream_eval(mut vm, 'var input=document.createElement("input"),area=document.createElement("textarea"),s=document.createElement("select");input.value="kept";area.value="retained";var option=document.createElement("option");option.value="chosen";s.appendChild(option);s.value="chosen"')!
	arena.leave(entry)
	for _, node in host.nodes {
		if element := node.as_element() {
			if element.local_name() == 'input' { assert !arena.contains(html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })) }
			if element.local_name() == 'textarea' { assert !arena.contains(html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })) }
		}
	}
	arena.reset(); arena.release()
	assert stream_eval(mut vm, 'input.value==="kept"&&area.value==="retained"&&s.value==="chosen"')!.as_bool()
}

fn test_cached_native_control_value_callbacks_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-controls-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert stream_eval(mut vm, 'function edit(e){e.value="compiled";return e.value}var e=document.createElement("input");edit(e)==="compiled"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 1 && stats.compiler_invocations == 0 && activity.entries >= 1 }
		vm.close_native_code()!
		host.close()
	}
}
