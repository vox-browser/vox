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
