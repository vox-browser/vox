module main

import browserjs
import css
import html

fn test_compact_initial_state_omits_unread_subtree_content() {
	document :=
		html.parse_document('<!doctype html><style>${'.large { color:red }'.repeat(4096)}</style><div><span>text</span></div>')
	state := javascript_initial_state(document, 'about:blank', [])
	assert 'bodyHTML' !in state
	assert 'bodyText' !in state
	elements := state['elements'] or { panic('missing elements') }
	for _, item in elements.as_map() {
		element_state := item.as_map()
		assert 'innerHTML' !in element_state
		assert 'textContent' !in element_state
	}
}

fn test_compact_content_getters_preserve_reads_pending_writes_and_cssom() {
	$if darwin {
		document :=
			html.parse_document('<!doctype html><style id="sheet">#result { color:red }</style><div id="parent"><span id="untouched">A &amp; B</span> tail</div><p id="result">old</p>')
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		mut messages := []string{}
		_ = run_document_script_sources(document, 'about:blank', [
			browserjs.ScriptSource{
				code: '
				const parentElement=document.getElementById("parent");
				if(parentElement.textContent !== "A & B tail") throw new Error("parent text");
				if(parentElement.innerHTML !== "<span id=\\"untouched\\">A &amp; B</span> tail") throw new Error("parent markup");
				if(document.body.innerHTML.indexOf("untouched") < 0) throw new Error("body markup");
				result.textContent="one"; result.textContent+=" two";
				if(result.textContent !== "one two") throw new Error("pending write");
				if(sheet.sheet.cssRules.length !== 1) throw new Error("style rules");
				sheet.sheet.cssRules[0].style.color="blue";
				console.log("lazy content passed");
			'
			},
		], runtime, mut messages)
		assert messages == ['lazy content passed']
		result := document.get_element_by_id('result') or { panic('missing result') }
		assert (result.as_node().text_content() or { '' }) == 'one two'
		style := document.get_element_by_id('sheet') or { panic('missing sheet') }
		// CSSOM edits update the live sheet without rewriting authored markup.
		assert (style.as_node().text_content() or { '' }) == '#result { color:red }'
		assert css.style_sheet_for_owner_node(document, style)?.css_rules().item(0)?.style()?.get_property_value('color') == 'blue'
		// Initial bridge indexes continue to identify their native nodes after
		// a new element changes document tree order.
		body := document.body() or { panic('missing body') }
		mut body_node := body.as_node()
		inserted := document.create_element('div')!
		mut inserted_node := inserted.as_node()
		inserted_node.set_text_content('inserted')!
		body_node.insert_before(inserted_node, body_node.first_child(), false)
		untouched := document.get_element_by_id('untouched') or { panic('missing untouched') }
		mut untouched_node := untouched.as_node()
		untouched_node.set_text_content('live content')!
		assert runtime.evaluate_host('untouched.textContent')! == 'live content'
		assert runtime.evaluate_host('parentElement.innerHTML.indexOf("live content") >= 0')! == 'true'
	}
}
