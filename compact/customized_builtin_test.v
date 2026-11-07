module main

import browserjs
import dom

// Customized built-in elements keep their definition through
// createElement(name, {is}) and cloneNode(), both of which upgrade the new
// element before returning it.
fn test_compact_customized_built_ins_upgrade_when_created_and_cloned() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><body><div id=host></div></body>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
class MyAnchor extends HTMLAnchorElement {}
customElements.define("my-anchor",MyAnchor,{extends:"a"});
const constructed=new MyAnchor(),created=document.createElement("a",{is:"my-anchor"});
const host=document.getElementById("host");host.innerHTML="<a is=my-anchor></a>";
console.log([constructed,created,host.firstChild,constructed.cloneNode(false),created.cloneNode(true)].map(element=>element.constructor===MyAnchor&&element.localName==="a").join(" "));
console.log(document.createElement("a",{is:"undefined-name"}).constructor===HTMLAnchorElement);
'], runtime, mut messages)
	assert messages == ['true true true true true', 'true'], messages.str()
}
