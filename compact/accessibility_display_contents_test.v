module main

import browserjs
import html

fn test_accessible_display_contents_keeps_visible_text_and_respects_hidden_ancestors() {
	mut document := html.parse_document('<!doctype html><div role="button" id="contents" style="display:contents">x</div><span>outside</span><div role="button" id="nested" style="display:contents"><span style="display:contents">nested</span></div><div role="button" id="aria" style="display:contents" aria-hidden="true">hidden</div><div role="button" id="visibility" style="display:contents;visibility:hidden">hidden</div><div style="display:none"><div role="button" id="ancestor" style="display:contents">hidden</div></div><div style="visibility:hidden"><div role="button" id="visible" style="display:contents;visibility:visible">shown</div></div><button id="none" style="display:none">hidden</button>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const expected={contents:"x",nested:"nested",aria:"",visibility:"",ancestor:"",visible:"shown",none:""};
for(const id of Object.keys(expected)){
    const actual=internals.getComputedLabel(document.getElementById(id));
    if(actual!==expected[id])throw new Error(id+": "+JSON.stringify(actual));
}
console.log("accessible display contents passed");
'], runtime, mut messages)
	assert messages == ['accessible display contents passed']
}
