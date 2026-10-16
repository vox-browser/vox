module main

import browserjs
import html

// Wikipedia's portal script reaches the language picker's container through
// select.parentNode.parentNode and inserts its label with parentNode.insertBefore.
fn test_compact_elements_expose_their_parents() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="outer" class="styled-select no-js"><div id="arrow" class="hide-arrow"><select id="language"><option value="en">English</option></select></div></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['
		const select = document.getElementById("language");
		const label = document.createElement("label");
		label.textContent = select.value;
		select.parentNode.parentNode.className = " styled-select js-enabled";
		select.parentNode.insertBefore(label, select);
		globalThis.result = [select.parentElement.id, select.parentNode.parentNode.id,
			label.parentNode.id, document.documentElement.parentNode === document,
			document.documentElement.parentElement === null].join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'arrow,outer,arrow,true,true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	outer := document.get_element_by_id('outer') or { panic('missing outer') }
	assert outer.get_attribute_value('class') == ' styled-select js-enabled'
	arrow := document.get_element_by_id('arrow') or { panic('missing arrow') }
	first := arrow.as_node().first_child() or { panic('missing label') }
	assert first.as_element()?.local_name() == 'label'
	assert messages == []
}

fn test_compact_class_list_replace_follows_dom_token_list() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><p id="target" class="a no-js b js-enabled"></p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['
		const list = document.getElementById("target").classList;
		globalThis.result = [list.replace("missing", "x"), list.replace("no-js", "js-enabled")].join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'false,true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_attribute_value('class') == 'a js-enabled b'
}
