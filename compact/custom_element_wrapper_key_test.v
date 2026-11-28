module main

import browserjs
import dom
import html
import os

// A new custom element and an element first reached as an event target get
// their wrapper from the key the providers hold for them, without refreshing
// the wheel host's map from every provider (which made each construction
// cost O(elements)). Identity, constructor state, event targets and
// listeners' receivers are unchanged.
fn test_new_custom_elements_and_event_targets_resolve_their_wrapper_key_directly() {
	mut rows := []string{}
	for index in 0 .. 300 {
		rows << '<div class="row" id="row-${index}"><span>row ${index}</span></div>'
	}
	address := dom.URL{value: 'https://wrapper-key.test/'}
	mut document := html.parse_navigation_document('<!doctype html><main id="main">${rows.join('')}</main>',
		address, address.origin(), none) or { panic(err) }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	direct_before, refreshed_before := browserjs.wheel_element_key_statistics()
	assert runtime.evaluate_host(r'
 const roots=new WeakMap();
 class Stamp extends HTMLElement{#root=this.attachShadow({mode:"open"});constructor(){super();roots.set(this,this.#root);this.made=true;}root(){return this.#root;}}
 customElements.define("x-stamp",Stamp);
 let events=0;
 main.addEventListener("ping",function(event){if(this!==main||!(event.target instanceof Stamp)||!event.target.made)throw Error("delegated listener");events++;});
 const made=[];
 for(let i=0;i<120;i++){
  const element=document.createElement("x-stamp");
  if(!(element instanceof Stamp)||!element.made||roots.get(element)!==element.root()||element.shadowRoot!==element.root())throw Error("construction "+i);
  element.id="stamp-"+i;main.appendChild(element);made.push(element);
  element.addEventListener("ping",function(event){if(this!==element||event.target!==element||event.currentTarget!==element)throw Error("own listener "+i);events++;});
  element.dispatchEvent(new Event("ping",{bubbles:true}));
 }
 for(let i=0;i<120;i++){if(document.getElementById("stamp-"+i)!==made[i]||main.children[300+i]!==made[i])throw Error("identity "+i);}
 // Parsed elements first reached through an event keep their wrappers.
 const row=document.getElementById("row-7");
 let rowEvents=0;main.addEventListener("pong",event=>{if(event.target!==row)throw Error("parsed target");rowEvents++;});
 row.dispatchEvent(new Event("pong",{bubbles:true}));
 events===240&&rowEvents===1;
 ')! == 'true'
	assert messages == []string{}, messages.str()
	direct_after, refreshed_after := browserjs.wheel_element_key_statistics()
	if os.getenv('VOX_RETAIN_WHEEL_ELEMENT_REFRESH') == '' {
		assert direct_after - direct_before >= 120
		assert refreshed_after == refreshed_before
	}
}
