module main

import browserjs
import html

fn test_native_accessible_ownership_is_unique_and_tracks_attribute_and_id_changes() {
	mut document := html.parse_document('<!doctype html><div role="button" id="first" aria-owns="shared">first </div><div role="button" id="second" aria-owns="shared">second </div><h4 id="original">original <span id="shared">shared</span></h4><button id="playbutton" aria-owns="play"><div aria-hidden="true"><span id="play">Play</span><span>Pause</span></div></button><button id="render-hidden" aria-owns="css-hidden">visible</button><div style="display:none"><span id="css-hidden">hidden</span></div><button id="aria-hidden-owner" aria-owns="aria-hidden-text">visible</button><span id="aria-hidden-text" aria-hidden="true">hidden</span><div role="button" id="order" aria-owns="b a b"><div id="a">A</div><div id="b">B</div><div>tail</div></div><div role="button" id="cycle-a" aria-owns="cycle-b">A</div><div role="button" id="cycle-b" aria-owns="cycle-a">B</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
try {
 const node=id=>document.getElementById(id), label=id=>internals.getComputedLabel(node(id));
 const expect=(id,value)=>{const actual=label(id);if(actual!==value)throw new Error(id+": "+JSON.stringify(actual));};
 expect("first","first shared");expect("second","second");expect("original","original");
 expect("playbutton","Play");expect("render-hidden","visible");expect("aria-hidden-owner","visible");
 expect("order","tail B A");expect("cycle-a","A B");expect("cycle-b","B");
 node("first").removeAttribute("aria-owns");
 expect("first","first");expect("second","second shared");expect("original","original");
 node("second").setAttribute("aria-hidden","true");expect("original","original shared");
 node("second").removeAttribute("aria-hidden");expect("original","original");
 node("shared").setAttribute("id","renamed");expect("second","second");expect("original","original shared");
 node("second").setAttribute("aria-owns","renamed");expect("second","second shared");expect("original","original");
 console.log("ownership names passed");
}catch(error){console.log("ownership failure: "+String(error));throw error;}
'], runtime, mut messages)
	assert messages == ['ownership names passed']
}
