module main

import browserjs
import html

fn test_accessible_text_preserves_inline_adjacency_and_block_separation() {
	mut document := html.parse_document('<!doctype html><button id="empty">button<span></span>label</button><h3 id="comment">heading<!-- boundary -->label</h3><a id="inline" href="#">link<span>text</span>label</a><button id="space">button<span> </span>label</button><div role="button" id="block">first<div>second</div></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const expected={empty:"buttonlabel",comment:"headinglabel",inline:"linktextlabel",space:"button label",block:"first second"};
for(const id of Object.keys(expected)){
    const actual=internals.getComputedLabel(document.getElementById(id));
    if(actual!==expected[id])throw new Error(id+": "+JSON.stringify(actual));
}
console.log("accessible text spacing passed");
'], runtime, mut messages)
	assert messages == ['accessible text spacing passed']
}
