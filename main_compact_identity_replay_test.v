module main

import browserjs
import css
import dom
import html
import x.json2

fn test_compact_initial_named_elements_preserve_duplicate_id_identity() {
	$if darwin {
		document :=
			html.parse_document('<!doctype html><div id="duplicate">first</div><span id="duplicate">second</span><img id="picture"><canvas id="drawing"></canvas>')
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		mut messages := []string{}
		_ = run_document_script_sources(document, 'about:blank', [
			browserjs.ScriptSource{
				code: '
				const original=duplicate;
				if(original!==document.querySelector("div")||original.textContent!=="first")throw new Error("named duplicate identity");
				if(picture!==document.getElementById("picture")||drawing!==document.getElementById("drawing"))throw new Error("specialized facade identity");
				original.remove();
				if(document.getElementById("duplicate").textContent!=="second")throw new Error("live ID lookup");
				original.textContent="detached";
				if(original.textContent!=="detached"||duplicate!==original)throw new Error("retained source identity");
				console.log("named identity passed");
			'
			},
		], runtime, mut messages)
		assert messages == ['named identity passed']
		assert (document.get_element_by_id('duplicate') or { panic('missing second') }).local_name() == 'span'
	}
}

fn test_compact_unbound_index_fallback_keeps_pre_replacement_tree() {
	document := html.parse_document('<!doctype html><p id="old">old</p>')
	old := document.get_element_by_id('old') or { panic('missing old') }
	mut state := javascript_initial_state(document, 'about:blank', [])
	mut elements := map[string]json2.Any{}
	for index, element in css.query_selector_all(unsafe { &dom.Node(document) }, '*') {
		if voidptr(element) != voidptr(old) { continue
		 }
		elements['__element_${index}'] = json2.Any({
			'bridgeKey':        json2.Any('__element_${index}')
			'elementIndex':     json2.Any(index)
			'textContent':      json2.Any('updated detached')
			'textContentDirty': json2.Any(true)
		})
	}
	assert elements.len == 1
	state['elements'] = json2.Any(elements)
	state['bodyHTMLDirty'] = json2.Any(true)
	state['bodyHTML'] = json2.Any('<p id="new">new</p>')
	mut messages := []string{}
	apply_javascript_state(document, json2.encode(state), map[string]&dom.Element{}, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('old') == none
	assert (old.as_node().text_content() or { '' }) == 'updated detached'
	assert ((document.get_element_by_id('new') or { panic('missing new') }).as_node().text_content() or {
		''
	}) == 'new'
}
