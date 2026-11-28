// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import platform

fn test_validity_state_interface_descriptors_and_illegal_constructor() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),v=e.validity,ok=v instanceof ValidityState&&v===e.validity&&Object.keys(v).length===0&&Object.prototype.toString.call(v)==="[object ValidityState]",caught=0;for(var call of [()=>ValidityState(),()=>new ValidityState()])try{call()}catch(x){if(x instanceof TypeError)caught++}for(var key of ["valueMissing","typeMismatch","patternMismatch","tooLong","tooShort","rangeUnderflow","rangeOverflow","stepMismatch","badInput","customError","valid"]){var d=Object.getOwnPropertyDescriptor(ValidityState.prototype,key);ok=ok&&d.enumerable&&d.configurable&&d.set===undefined&&d.get.length===0&&v[key]===(key==="valid")}ok&&caught===2&&ValidityState.length===0&&!Object.getOwnPropertyDescriptor(ValidityState,"prototype").writable')!.as_bool()
}

fn test_control_validity_state_is_live_across_value_and_required_changes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),v=e.validity;e.required=true;var first=v.valueMissing&&!v.valid&&!e.checkValidity();e.value="present";var second=v.valid&&!v.valueMissing&&e.checkValidity();e.value="";e.required=false;first&&second&&v.valid&&e.validity===v')!.as_bool()
}

fn test_custom_validity_preserves_domstring_conversion_and_normalizes_newlines() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("textarea"),v=e.validity;e.setCustomValidity("one\\r\\ntwo\\rthree");var first=v.customError&&!v.valid&&e.validationMessage==="one\\ntwo\\nthree";e.setCustomValidity(null);var second=e.validationMessage==="null";e.setCustomValidity(undefined);var third=e.validationMessage==="undefined";e.setCustomValidity("");first&&second&&third&&!v.customError&&v.valid&&e.validationMessage===""')!.as_bool()
}

fn test_invalid_event_uses_native_cancelable_dispatch_and_return_value() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),e=document.createElement("input"),events=[],bubbles=0;f.appendChild(e);document.body.appendChild(f);f.addEventListener("invalid",()=>bubbles++);e.addEventListener("invalid",x=>{events.push(x.target===e&&x.currentTarget===e&&!x.bubbles&&x.cancelable&&x.isTrusted);x.preventDefault()});e.required=true;var first=!e.checkValidity()&&!e.reportValidity();e.disabled=true;var second=e.checkValidity()&&e.reportValidity();first&&second&&events.length===2&&events.every(Boolean)&&bubbles===0')!.as_bool()
	assert stream_eval(mut vm, 'e.disabled=false;e.required=false;e.setCustomValidity("invalid");e.addEventListener("invalid",()=>e.setCustomValidity(""));!e.checkValidity()&&e.validity.valid')!.as_bool()
}

fn test_validation_barred_controls_keep_their_custom_error_state() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var ok=true;for(var tag of ["input","textarea","select","button"]){var e=document.createElement(tag);e.setCustomValidity("kept");e.disabled=true;ok=ok&&!e.willValidate&&e.validationMessage===""&&e.validity.customError&&!e.validity.valid&&e.checkValidity();e.disabled=false;e.setCustomValidity("");ok=ok&&e.validity.valid}var i=document.createElement("input");i.type="hidden";ok=ok&&!i.willValidate;i.type="text";i.readOnly=true;ok=ok&&!i.willValidate;var a=document.createElement("textarea");a.readOnly=true;var b=document.createElement("button");b.type="button";ok&&!a.willValidate&&!b.willValidate')!.as_bool()
}

fn test_validation_brand_checks_precede_message_conversion_and_preserve_throws() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input"),reads=0,caught=0,arg={toString(){reads++;return "invalid"}};for(var receiver of [{},document.createElement("textarea"),new Proxy(e,{})])try{HTMLInputElement.prototype.setCustomValidity.call(receiver,arg)}catch(x){if(x instanceof TypeError)caught++}try{e.setCustomValidity()}catch(x){if(x instanceof TypeError)caught++}var get=Object.getOwnPropertyDescriptor(ValidityState.prototype,"valid").get;for(var receiver of [{},e,new Proxy(e.validity,{})])try{get.call(receiver)}catch(x){if(x instanceof TypeError)caught++}var marker={},same=false;try{e.setCustomValidity({toString(){throw marker}})}catch(x){same=x===marker}caught===7&&reads===0&&same&&e.validity.valid')!.as_bool()
}

fn test_number_and_email_constraints_reach_native_owners() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var e=document.createElement("input");e.type="number";e.min="1";e.max="10";e.step="2";e.value="5";var v=e.validity,ok=v.valid;e.value="6";ok=ok&&v.stepMismatch&&!v.valid;e.value="0";ok=ok&&v.rangeUnderflow;e.value="11";ok=ok&&v.rangeOverflow;e.type="email";e.value="invalid";ok=ok&&v.typeMismatch;e.value="valid@example.test";ok&&v.valid')!.as_bool()
}

fn test_textarea_and_select_validity_follow_default_and_selectedness_changes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var a=document.createElement("textarea"),s=document.createElement("select"),p=document.createElement("option"),o=document.createElement("option");a.required=true;a.defaultValue="initial";var av=a.validity,ok=av.valid;a.defaultValue="";ok=ok&&av.valueMissing;a.value="edited";a.defaultValue="";ok=ok&&av.valid;p.value="";p.text="Choose";o.value="v";s.appendChild(p);s.appendChild(o);s.required=true;var sv=s.validity;ok=ok&&sv.valueMissing;s.value="v";ok=ok&&sv.valid;s.selectedIndex=-1;ok&&sv.valueMissing')!.as_bool()
}

fn test_form_validation_and_submit_prevention_share_control_validity() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),s=document.createElement("select"),o=document.createElement("option"),invalid=0,submitted=0;s.name="choice";s.required=true;o.value="";s.appendChild(o);f.appendChild(s);document.body.appendChild(f);s.addEventListener("invalid",()=>invalid++);f.addEventListener("submit",x=>{submitted++;x.preventDefault()});var first=!f.checkValidity();f.requestSubmit();s.required=false;f.requestSubmit();first&&invalid===2&&submitted===1&&f.checkValidity()')!.as_bool()
}

fn test_validity_state_uses_intrinsic_prototype_and_rejects_history_clone() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var Saved=ValidityState;globalThis.ValidityState=function(){throw "public constructor"};var e=document.createElement("input"),v=e.validity,clone=false;try{history.replaceState(v,"")}catch(x){clone=x.name==="DataCloneError"}globalThis.ValidityState=Saved;v instanceof Saved&&clone&&v===e.validity')!.as_bool()
}

fn test_validity_state_bindings_survive_transient_arena_reset_and_close() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('validity state bindings')
	entry := arena.enter()
	stream_eval(mut vm, 'var e=document.createElement("input");e.required=true;var v=e.validity')!
	arena.leave(entry)
	assert host.validity_states.len == 1 && host.validity_state_wrappers.len == 1
	for _, state in host.validity_states { assert !arena.contains(state) }
	for _, object in host.validity_state_wrappers { assert !arena.contains(object) }
	arena.reset()
	assert stream_eval(mut vm, 'v.valueMissing&&!v.valid&&(e.value="kept",v.valid)')!.as_bool()
	host.close()
	assert host.validity_states.len == 0 && host.validity_state_wrappers.len == 0
}
