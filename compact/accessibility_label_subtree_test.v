module main

import browserjs
import html

fn test_native_accessible_label_wrappers_keep_live_controls_and_visibility() {
	mut document := html.parse_document('<!doctype html><label role="none"><span>input <b>label</b></span><span><input id="plain" role="none" value="excluded"></span></label><label for="times"><span>Repeat <b><input id="count" value="7"></b> times</span><span><textarea id="times">excluded</textarea></span><span aria-hidden="true">ignored</span><span style="visibility:hidden">hidden<span style="visibility:visible"> shown</span></span></label><label for="hidden" style="display:none"><span>Hidden label</span></label><input id="hidden">')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const label=id=>internals.getComputedLabel(document.getElementById(id));
if(label("plain")!=="input label")throw new Error("wrapper "+label("plain"));
if(label("times")!=="Repeat 7 times shown")throw new Error("nested controls "+label("times"));
count.value="9";
if(label("times")!=="Repeat 9 times shown")throw new Error("live control "+label("times"));
if(label("hidden")!=="Hidden label")throw new Error("hidden referenced label "+label("hidden"));
console.log("nested accessible labels passed");
'], runtime, mut messages)
	assert messages == ['nested accessible labels passed']
}
