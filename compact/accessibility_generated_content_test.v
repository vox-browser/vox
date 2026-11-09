module main

import browserjs
import html

fn test_accessible_generated_alternatives_replace_visual_text_and_stay_with_their_owner() {
	mut document := html.parse_document('<!doctype html><style>.alt::before{content:"visual" / "before "}.alt::after{content:"visual" / " after"}.empty::before{content:"visual" / ""}.child::before{content:"visual" / "child "}</style><button id="alt" class="alt">label</button><button id="empty" class="empty">label</button><button id="parent"><span class="child">label</span></button>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const label=id=>internals.getComputedLabel(document.getElementById(id));
if(label("alt")!=="before label after")throw new Error("alternatives "+label("alt"));
if(label("empty")!=="label")throw new Error("empty alternative "+label("empty"));
if(label("parent")!=="child label")throw new Error("pseudo owner "+label("parent"));
console.log("generated alternatives passed");
'], runtime, mut messages)
	assert messages == ['generated alternatives passed']
}

fn test_accessible_counter_alternatives_are_isolated_and_follow_cssom_updates() {
	mut document := html.parse_document('<!doctype html><style>:root{counter-reset:seq}.seq::before{counter-increment:seq;content:"" / counter(seq) " "}.changed::before{counter-set:cnt 50;content:"" / counter(cnt) " "}</style><button id="one" class="seq">label</button><button id="two" class="seq">label</button><button id="three" class="seq">label</button><button id="changed" class="changed">label</button>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const label=id=>internals.getComputedLabel(document.getElementById(id));
for(const [id,value] of [["one","1 label"],["two","2 label"],["three","3 label"],["changed","50 label"]]){
 if(label(id)!==value)throw new Error(id+": "+label(id));
}
document.styleSheets[0].cssRules[2].style.counterSet="cnt 228";
if(label("changed")!=="228 label")throw new Error("counter invalidation "+label("changed"));
if(label("one")!=="1 label"||label("two")!=="2 label")throw new Error("counter isolation");
console.log("counter alternatives passed");
'], runtime, mut messages)
	assert messages == ['counter alternatives passed']
}
