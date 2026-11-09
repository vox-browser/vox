module main

import browserjs
import html

// 4chan's ad loader builds its frames from IDL properties. They must reach the
// DOM as content attributes: frameborder="0" removes the default inset border.
fn test_compact_iframe_reflects_presentational_properties() {
	$if !darwin && !linux {
		return
	}
	document := html.parse_document('<!doctype html><html><body><div id="slot"></div><iframe id="parsed" frameborder="0" loading="LAZY" referrerpolicy="bogus"></iframe></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', ['
		const gate = document.createElement("iframe");
		gate.marginHeight = 0;
		gate.frameBorder = 0;
		gate.scrolling = "no";
		gate.marginWidth = null;
		gate.loading = "eager";
		gate.allow = "autoplay";
		gate.allowFullscreen = 1;
		gate.srcdoc = "<b>inline</b>";
		gate.id = "gate";
		document.getElementById("slot").appendChild(gate);
		const parsed = document.getElementById("parsed");
		let symbolError = "";
		try { gate.frameBorder = Symbol("x"); } catch (error) { symbolError = error.constructor.name; }
		globalThis.result = [gate.frameBorder, gate.marginHeight, gate.marginWidth, gate.scrolling,
			gate.loading, gate.allow, gate.allowFullscreen, parsed.frameBorder, parsed.loading,
			JSON.stringify(parsed.referrerPolicy), parsed.allowFullscreen, symbolError,
			"frameBorder" in document.createElement("div"),
			Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, "frameBorder").enumerable,
			gate.srcdoc, JSON.stringify(parsed.srcdoc)].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == '0|0||no|eager|autoplay|true|0|lazy|""|false|TypeError|false|true|<b>inline</b>|""'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	gate := document.get_element_by_id('gate') or { panic('missing inserted iframe') }
	assert gate.get_attribute_value('frameborder') == '0'
	assert gate.get_attribute_value('marginheight') == '0'
	assert gate.get_attribute_value('marginwidth') == ''
	assert gate.has_attribute('marginwidth')
	assert gate.get_attribute_value('scrolling') == 'no'
	assert gate.get_attribute_value('loading') == 'eager'
	assert gate.get_attribute_value('allow') == 'autoplay'
	assert gate.has_attribute('allowfullscreen')
	assert gate.get_attribute_value('srcdoc') == '<b>inline</b>'
	assert messages == []
}
