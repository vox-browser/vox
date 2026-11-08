module main

import browserjs
import html

fn test_constraint_validation_api_reads_native_validity() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><form id="f"><input id="req" required><input id="num" type="number" min="5" value="2"><input id="hidden" type="hidden" required><textarea id="area" required></textarea><fieldset id="set"></fieldset></form>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'let invalid=0;req.addEventListener("invalid",()=>invalid++);console.log(req.validity instanceof ValidityState,req.validity===req.validity,req.validity.valueMissing,req.validity.valid,req.willValidate,num.validity.rangeUnderflow,hidden.willValidate,area.validity.valueMissing,set.willValidate,set.checkValidity());console.log(req.checkValidity(),invalid,f.checkValidity());req.value="x";num.value="7";area.value="t";console.log(req.validity.valid,f.checkValidity());req.setCustomValidity("bad");console.log(req.validity.customError,req.validationMessage,req.checkValidity());req.setCustomValidity("");console.log(req.validity.valid);',
	], runtime, mut messages)
	assert messages == ['true true true false true true false true false true', 'false 1 false',
		'true true', 'true bad false', 'true']
}

fn test_autocomplete_reads_the_autofill_field_and_form_state() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><form id="off" autocomplete="OFF"><input id="plain"><input id="on" autocomplete="on"></form><form id="bad" autocomplete="foo"></form>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const input=document.createElement("input");input.setAttribute("autocomplete"," NAME\\t");const area=document.createElement("textarea");area.setAttribute("autocomplete","  section-FOO  shipping work tel webauthn ");const hidden=document.createElement("input");hidden.type="hidden";hidden.autocomplete="on";const select=document.createElement("select");select.setAttribute("autocomplete","foo off");console.log([off.autocomplete,bad.autocomplete,plain.autocomplete,on.autocomplete,input.autocomplete,area.autocomplete,hidden.autocomplete,hidden.getAttribute("autocomplete"),select.autocomplete].join("|"));',
	], runtime, mut messages)
	assert messages == ['off|on||on|name|section-foo shipping work tel webauthn||on|']
}

fn test_show_picker_requires_a_mutable_input_and_user_activation() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><input id="disabled" disabled><input id="readonly" readonly><input id="plain">')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const names=[];for(const input of [disabled,readonly,plain]){try{input.showPicker();names.push("none");}catch(error){names.push((error instanceof DOMException)+" "+error.name);}}console.log(names.join("|"));',
	], runtime, mut messages)
	assert messages == ['true InvalidStateError|true InvalidStateError|true NotAllowedError']
}
