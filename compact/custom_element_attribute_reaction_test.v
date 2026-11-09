module main

import browserjs
import dom

// Attribute writes are [CEReactions]: attributeChangedCallback runs before
// setAttribute(), removeAttribute() and reflecting setters return.
fn test_compact_custom_element_attribute_reactions_run_before_the_write_returns() {
	$if !darwin && !linux {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><body></body>', dom.URL{
		value: 'https://example.test/'
	}, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const logs=[];
class Observed extends HTMLElement{static get observedAttributes(){return ["aria-atomic","x"];}attributeChangedCallback(name,old,value){logs.push(name+"="+value);}}
customElements.define("x-observed",Observed);
const element=new Observed();
element.setAttribute("x","1");const afterSet=logs.join(",");
element.ariaAtomic="true";const afterReflect=logs.join(",");
element.removeAttribute("x");
console.log([afterSet,afterReflect,logs.join(",")].join(" | "));
'], runtime, mut messages)
	assert messages == ['x=1 | x=1,aria-atomic=true | x=1,aria-atomic=true,x=null'], messages.str()
}
