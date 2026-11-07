module main

import browserjs
import dom

// transform-origin resolves like height: percentages become pixels of the
// box, and a non-zero z offset follows.
fn test_compact_transform_origin_resolves_against_the_box() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><div id=a style="width:50px;height:40px"></div><div id=b style="width:50px;height:40px;transform-origin:10px 25% 3px"></div><div id=c style="display:none;transform-origin:left"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
console.log(["a","b","c"].map(id=>getComputedStyle(document.getElementById(id)).transformOrigin).join(" | "));
'], runtime, mut messages)
	assert messages == ['25px 20px | 10px 10px 3px | 0% 50%'], messages.str()
}
