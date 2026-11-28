module main

import browserjs
import dom
import html
import os

// A native attribute write publishes the facade's pending edits first. With
// nothing pending it only settles custom element reactions instead of
// replaying an empty snapshot; a pending edit still lands before the write,
// and attribute reactions still run.
fn test_attribute_writes_replay_only_pending_facade_edits() {
	url := dom.URL{value: 'https://attribute-replay.test/'}
	mut document := html.parse_navigation_document('<!doctype html><body><div id="a">old</div><div id="b"></div></body>',
		url, url.origin(), none) or { panic(err) }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	retained := os.getenv('VOX_RETAIN_TRUSTED_ATTRIBUTE_REPLAYS') != ''
	settled_before := compact_settled_attribute_writes
	assert runtime.evaluate_host(r'
 const a=document.getElementById("a"),b=document.getElementById("b");
 for(let i=0;i<20;i++)b.setAttribute("data-n",String(i));
 b.getAttribute("data-n")==="19";
 ')! == 'true'
	if !retained {
		assert compact_settled_attribute_writes - settled_before >= 20
	}
	b := document.get_element_by_id('b') or { panic('b') }
	assert b.get_attribute_value('data-n') == '19'
	// A pending text edit is published before the next attribute write.
	assert runtime.evaluate_host(r'
 globalThis.first=document.getElementById("a");globalThis.second=document.getElementById("b");
 true;
 ')! == 'true'
	settled_pending := compact_settled_attribute_writes
	// The text edit stays pending in the facade (a query would publish it).
	assert runtime.evaluate_host(r'
 first.textContent="new";
 second.setAttribute("data-after","1");
 true;
 ')! == 'true'
	assert compact_settled_attribute_writes == settled_pending
	a := document.get_element_by_id('a') or { panic('a') }
	assert a.as_node().text_content() or { '' } == 'new'
	assert b.get_attribute_value('data-after') == '1'
	// Reactions to the write itself run before setAttribute returns.
	assert runtime.evaluate_host(r'
 const seen=[];
 class Watched extends HTMLElement{static get observedAttributes(){return ["data-z"];}attributeChangedCallback(name,old,value){seen.push(name+":"+old+":"+value);}}
 customElements.define("x-watched",Watched);
 const watched=document.createElement("x-watched");document.body.appendChild(watched);
 watched.setAttribute("data-z","1");const first=seen.join();
 watched.setAttribute("data-z","2");
 first==="data-z:null:1"&&seen.join()==="data-z:null:1,data-z:1:2";
 ')! == 'true'
}
