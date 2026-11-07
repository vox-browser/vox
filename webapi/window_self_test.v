module main

import browserjs
import html

fn test_compact_page_bundles_can_use_window_self_as_their_global() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/maps/', [
		'if (!("document" in window.self)) throw new Error("missing document"); (self.chunks ||= []).push("map"); result.textContent = self === window && self === globalThis ? self.chunks[0] : "wrong global";',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'map'
}
