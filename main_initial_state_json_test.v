module main

import browserjs
import html
import strings

fn test_compact_initial_state_preserves_json_attribute_names_and_escaped_values() {
	$if !darwin && !linux { return }
	mut document := html.parse_document('<!doctype html><div id="target" __proto__="raw attribute" data-value="&quot;quoted&quot; &amp; &lt;/script&gt; Привет 世界"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://initial-state.test/', [], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('target.getAttribute("__proto__")==="raw attribute" && target.getAttribute("data-value")===\'"quoted" & </script> Привет 世界\'')! == 'true'
	assert runtime.evaluate_host('(()=>{const s=JSON.parse(__ladybirdSnapshot()),r=Object.values(s.elements).find(e=>e.id==="target");return Object.hasOwn(r.attributes,"__proto__")&&r.attributes.__proto__==="raw attribute"&&Object.getPrototypeOf(r.attributes)===Object.prototype})()')! == 'true'
}

fn test_large_compact_initial_state_keeps_element_identity_records_and_mutation_replay() {
	$if !darwin && !linux { return }
	mut markup := strings.new_builder(128_000)
	markup.write_string('<!doctype html><main id="root">')
	for index in 0 .. 1500 {
		markup.write_string('<span id="entry${index}" class="item" data-index="${index}" data-value="line&#10;quote&quot;slash&#92;">row ${index}</span>')
	}
	markup.write_string('</main>')
	mut document := html.parse_document(markup.str())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://initial-state.test/', [], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('document.querySelectorAll(".item").length')! == '1500'
	assert runtime.evaluate_host('entry1499===document.querySelector("#entry1499") && entry1499.getAttribute("data-index")==="1499" && entry1499.getAttribute("data-value")==="line"+String.fromCharCode(10)+"quote"+String.fromCharCode(34)+"slash"+String.fromCharCode(92)')! == 'true'
	runtime.evaluate_host('entry1499.setAttribute("data-index","changed");entry1499.textContent="updated"')!
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	target := document.get_element_by_id('entry1499')?
	assert target.get_attribute_value('data-index') == 'changed'
	assert target.as_node().text_content()? == 'updated'
	assert messages == []string{}
}
