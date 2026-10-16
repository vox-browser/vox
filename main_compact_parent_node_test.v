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
			document.documentElement.parentElement === null, select.value].join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'arrow,outer,arrow,true,true,en'
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

// Wikipedia's language picker reads select.value for its label and padding.
fn test_compact_select_exposes_its_value() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><select id="a"><option value="en">English</option><option value="de" selected>Deutsch</option></select><select id="b"><option>Plain</option></select><div id="c"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['
		"use strict";
		const a = document.getElementById("a"), b = document.getElementById("b"), c = document.getElementById("c");
		const before = [a.value, b.value, typeof c.value];
		c.value = 7;
		globalThis.result = before.concat([c.value]).join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'de,Plain,undefined,7'
	assert messages == []
}
