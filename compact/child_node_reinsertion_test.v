module main

import browserjs
import dom

// An element inserted again with before() after an earlier remove() can be
// removed again; the second removal used to be dropped, leaving :has() and
// the tree as they were.
fn test_compact_element_reinserted_with_before_can_be_removed_again() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><style>div{color:grey}div:has(> [test_attr]) ~ #subject{color:lightgreen}</style><main><div id=ps><div id=psc></div></div><div id=subject></div></main>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const subject=document.getElementById("subject"),psc=document.getElementById("psc"),color=()=>getComputedStyle(subject).color,out=[];
const b=document.createElement("div");psc.before(b);out.push(color());b.remove();out.push(color());
b.setAttribute("test_attr","");psc.before(b);out.push(color());b.remove();out.push(color());
out.push(document.getElementById("ps").children.length);
console.log(out.join(" "));
'], runtime, mut messages)
	assert messages == ['rgb(128, 128, 128) rgb(128, 128, 128) rgb(144, 238, 144) rgb(128, 128, 128) 1'], messages.str()
}
