// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import platform

fn test_text_control_selection_uses_utf16_offsets_and_normalized_textarea_newlines() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var i=document.createElement("input"),a=document.createElement("textarea");i.value="a😀bc";i.setSelectionRange(1,3,"backward");a.value="a\\r\\nb\\rc";a.setSelectionRange(2,3);i.selectionStart===1&&i.selectionEnd===3&&i.selectionDirection==="backward"&&i.value.slice(i.selectionStart,i.selectionEnd)==="😀"&&a.value==="a\\nb\\nc"&&a.selectionStart===2&&a.selectionEnd===3')!.as_bool()
}

fn test_text_control_selection_setters_clamp_wrap_and_collapse() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var ok=true;for(var tag of ["input","textarea"]){var e=document.createElement(tag);e.value="abcdef";e.setSelectionRange(1,4,"forward");e.selectionStart=5;ok=ok&&e.selectionStart===5&&e.selectionEnd===5;e.selectionEnd=2;ok=ok&&e.selectionStart===2&&e.selectionEnd===2;e.setSelectionRange(-1,3);ok=ok&&e.selectionStart===3&&e.selectionEnd===3;e.setSelectionRange(4294967297,4294967300);ok=ok&&e.selectionStart===1&&e.selectionEnd===4;e.selectionStart=null;e.selectionEnd=undefined;e.selectionDirection="other";ok=ok&&e.selectionStart===0&&e.selectionEnd===0&&e.selectionDirection==="none"}ok')!.as_bool()
}

fn test_text_selection_input_type_applicability_uses_dom_exceptions() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),caught=0;e.type="checkbox";for(var operation of [()=>e.selectionStart=1,()=>e.selectionEnd=1,()=>e.selectionDirection="forward",()=>e.setSelectionRange(0,1),()=>e.setRangeText("x")])try{operation()}catch(x){if(x instanceof DOMException&&x.name==="InvalidStateError")caught++}e.selectionStart===null&&e.selectionEnd===null&&e.selectionDirection===null&&e.select(Symbol())===undefined&&caught===5')!.as_bool()
}

fn test_text_selection_brand_and_overload_checks_precede_author_conversion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),reads=0,caught=0,arg={toString(){reads++;return "x"},valueOf(){reads++;return 1}},d=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,"selectionStart");for(var receiver of [{},document.createElement("textarea"),new Proxy(e,{})])try{d.set.call(receiver,arg)}catch(x){if(x instanceof TypeError)caught++}for(var call of [()=>e.setSelectionRange(arg),()=>e.setRangeText(),()=>e.setRangeText(arg,arg)])try{call()}catch(x){if(x instanceof TypeError)caught++}reads===0&&caught===6')!.as_bool()
}

fn test_text_selection_conversion_order_observes_live_type_and_value() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),order=[];e.type="checkbox";e.setSelectionRange({valueOf(){order.push("start");e.type="text";e.value="abcdef";return 1}},{valueOf(){order.push("end");return 4}},{toString(){order.push("direction");return "backward"}});var first=e.selectionStart===1&&e.selectionEnd===4&&e.selectionDirection==="backward";e.selectionStart={valueOf(){e.value="xyz";return 2}};first&&order.join()==="start,end,direction"&&e.selectionStart===2&&e.selectionEnd===3')!.as_bool()
}

fn test_set_range_text_modes_use_real_control_values_and_selection() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var ok=true;for(var tag of ["input","textarea"])for(var mode of ["select","start","end","preserve"]){var e=document.createElement(tag);e.value="abcdefgh";e.setSelectionRange(2,6,"backward");e.setRangeText("X",3,5,mode);var start=mode==="preserve"?2:mode==="end"?4:3,end=mode==="preserve"?5:mode==="start"?3:4;ok=ok&&e.value==="abcXfgh"&&e.selectionStart===start&&e.selectionEnd===end&&e.selectionDirection==="none"}ok')!.as_bool()
}

fn test_set_range_text_one_argument_reads_selection_after_replacement_conversion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("textarea");e.value="abcdef";e.setSelectionRange(0,0);e.setRangeText({toString(){e.setSelectionRange(1,3);return null}});e.value==="anulldef"&&e.selectionStart===1&&e.selectionEnd===5')!.as_bool()
}

fn test_set_range_text_conversion_and_enum_errors_precede_native_applicability() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),order=[],caught=false;e.type="checkbox";try{e.setRangeText({toString(){order.push("replacement");return "x"}},{valueOf(){order.push("start");return 3}},{valueOf(){order.push("end");return 1}},{toString(){order.push("mode");return "invalid"}})}catch(x){caught=x instanceof TypeError}caught&&order.join()==="replacement,start,end,mode"')!.as_bool()
	assert stream_eval(mut vm, 'var marker={},same=false;try{e.setSelectionRange({valueOf(){throw marker}},2)}catch(x){same=x===marker}same')!.as_bool()
}

fn test_range_replacement_keeps_native_dirty_state_and_form_serialization() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),i=document.createElement("input"),a=document.createElement("textarea");i.name="i";a.name="a";i.defaultValue="base";a.defaultValue="base";f.appendChild(i);f.appendChild(a);document.body.appendChild(f);i.setRangeText("X",0,2,"select");a.setRangeText("Y",0,2,"end");i.defaultValue="other";a.defaultValue="other";var d=new FormData(f);i.value==="Xse"&&a.value==="Yse"&&d.get("i")==="Xse"&&d.get("a")==="Yse"')!.as_bool()
}

fn test_text_selection_descriptors_and_no_synchronous_input_events() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("textarea"),events=0;e.addEventListener("input",()=>events++);e.addEventListener("change",()=>events++);e.addEventListener("select",()=>events++);e.value="abc";e.select();e.setSelectionRange(0,1);e.setRangeText("X");var p=HTMLTextAreaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"selectionStart"),m=Object.getOwnPropertyDescriptor(p,"setSelectionRange");events===0&&d.enumerable&&d.configurable&&typeof d.get==="function"&&typeof d.set==="function"&&m.enumerable&&m.writable&&m.configurable&&p.select.length===0&&p.setRangeText.length===1&&p.setSelectionRange.length===2')!.as_bool()
}

fn test_text_selection_owners_survive_transient_arena_reset() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('text selection owners')
	entry := arena.enter()
	stream_eval(mut vm, 'var e=document.createElement("textarea");e.value="abcdef";e.setRangeText("X",1,3,"select")')!
	arena.leave(entry)
	for _, node in host.nodes {
		if element := node.as_element() {
			if element.local_name() == 'textarea' {
				model := html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
				assert !arena.contains(model) && !arena.contains(model.text)
			}
		}
	}
	arena.reset()
	assert stream_eval(mut vm, 'e.value==="aXdef"&&e.selectionStart===1&&e.selectionEnd===2')!.as_bool()
}
