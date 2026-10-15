module main

import browserjs
import html

fn test_compact_element_queries_keep_the_receiver_as_the_selector_scope() {
	$if !darwin { return }
	mut document :=
		html.parse_document('<!doctype html><section id="scope"><div class="story__main"><p id="scoped">Реклама. ИНН 1234567890</p></div><article><p id="nested">nested</p></article></section><div class="story__main"><p id="outside">outside</p></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const receiver=document.getElementById("scope");
const direct=receiver.querySelector(":scope > .story__main p");
if(direct!==document.getElementById("scoped"))throw new Error("querySelector lost the receiver scope");
const list=receiver.querySelectorAll(":scope > .story__main p");
if(list.length!==1||list[0]!==direct)throw new Error("querySelectorAll lost the receiver scope");
if(!/Реклама.* ИНН/i.test(list[0].textContent))throw new Error("scoped text was not preserved");
if(receiver.querySelector(":scope")!==null||receiver.querySelectorAll(":scope").length!==0)throw new Error("query included its own root");
if(document.querySelectorAll(".story__main p").length!==2)throw new Error("document query was restricted to an element scope");
if(document.querySelector(":scope > body")!==document.body)throw new Error("document scope did not select its document element");
const saved=receiver.querySelectorAll(":scope > .story__main p");
direct.remove();
if(receiver.querySelector(":scope > .story__main p")!==null||receiver.querySelectorAll(":scope > .story__main p").length!==0||saved.length!==1)throw new Error("scoped query did not observe native mutation");
console.log("scoped selectors passed");
',
	], runtime, mut messages)
	assert messages == ['scoped selectors passed']
}
