module main

import browserjs
import html

// Host callbacks such as animation frames replay __ladybirdFinalize() without
// clearing the logs afterwards. A content write must reach the document once:
// replaying it on every later callback re-parsed 4chan's 150 KB thread grid
// each frame.
fn test_finalize_reports_each_content_write_once() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><body><div id="threads"></div></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [''], runtime, mut messages)
	runtime.evaluate_host('document.getElementById("threads").innerHTML = "<div class=\\"thread\\">1</div>"; document.getElementById("threads").setAttribute("data-count", "1");')!
	first := runtime.evaluate_host('__ladybirdFinalize()')!
	assert first.contains('class=\\"thread\\"')
	apply_javascript_state(document, first, runtime.canvas_elements_for_binding(), mut messages)
	second := runtime.evaluate_host('__ladybirdFinalize()')!
	assert !second.contains('class=\\"thread\\"')
	assert !second.contains('data-count')
	threads := document.get_element_by_id('threads') or { panic('missing threads') }
	assert threads.inner_html()! == '<div class="thread">1</div>'
	assert threads.get_attribute_value('data-count') == '1'
	assert messages == []
}
