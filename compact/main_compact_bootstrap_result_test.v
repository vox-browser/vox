module main

import browserjs
import html
import x.json2

fn test_compact_bootstrap_avoids_unconsumed_full_snapshot_and_keeps_explicit_snapshots() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><p id="target">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	runtime.evaluate_host(r'
const originalStringify=JSON.stringify;
globalThis.wholeCompactSnapshots=0;
JSON.stringify=function(value){
 if(value&&value.elements&&Array.isArray(value.operations)&&Object.keys(value.elements).length===4)wholeCompactSnapshots++;
 return Reflect.apply(originalStringify,this,arguments);
};
')!
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert runtime.evaluate_host('String(wholeCompactSnapshots)')! == '0'
	full := json2.decode[map[string]json2.Any](runtime.evaluate_host('__ladybirdSnapshot()')!)!
	assert (full['elements'] or { panic('missing explicit snapshot elements') }).as_map().len == 4
	assert runtime.evaluate_host('String(wholeCompactSnapshots)')! == '1'
	runtime.evaluate_host('target.textContent="after initialization";console.log("snapshot available")')!
	updated := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, updated, runtime.canvas_elements_for_binding(), mut messages)
	runtime.evaluate_host('__ladybirdClearLogs()')!
	assert messages == ['snapshot available']
	assert (document.get_element_by_id('target') or { panic('missing target') }).as_node().text_content() or {
		''
	} == 'after initialization'
}
