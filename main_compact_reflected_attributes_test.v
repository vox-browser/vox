module main

import browserjs
import html

// 4chan's catalog creates its theme stylesheet link by assigning rel and type
// as properties, then inserts it into the head before #mobile-css.
fn test_compact_elements_reflect_link_attributes_set_as_properties() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><html><head><link id="mobile-css" rel="stylesheet" href="mobile.css"></head><body><a id="link" href="thread/1">thread</a><div id="plain"></div></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', ['
		const link = document.createElement("link");
		link.type = "text/css";
		link.id = "base-css";
		link.rel = "stylesheet";
		link.media = "screen";
		link.title = "switch";
		link.setAttribute("href", "//s.4cdn.org/css/catalog_yotsuba_new.705.css");
		document.head.insertBefore(link, document.getElementById("mobile-css"));
		const anchor = document.getElementById("link");
		globalThis.result = [link.rel, link.type, link.media, link.title, link.href, anchor.href,
			anchor.rel, document.getElementById("plain").href === undefined,
			document.getElementById("plain").rel === undefined].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'stylesheet|text/css|screen|switch|https://s.4cdn.org/css/catalog_yotsuba_new.705.css|https://boards.4chan.org/pol/thread/1||true|true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	link := document.get_element_by_id('base-css') or { panic('missing inserted link') }
	assert link.get_attribute_value('rel') == 'stylesheet'
	assert link.get_attribute_value('type') == 'text/css'
	assert link.get_attribute_value('media') == 'screen'
	assert link.get_attribute_value('title') == 'switch'
	next := link.as_node().next_sibling() or { panic('missing next sibling') }
	assert next.as_element()?.get_attribute_value('id') == 'mobile-css'
	assert messages == []
}
