module main

import browserjs
import html

fn test_element_reflecting_attributes_resolve_ids_and_explicit_elements() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="a">a</div><div id="b">b</div><button id="button" aria-controls="a  b missing" aria-activedescendant="b" popovertarget="a" commandfor="b">x</button><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'console.log(button.ariaControlsElements.map(e=>e.id).join(","),button.ariaActiveDescendantElement.id,button.popoverTargetElement.id,button.commandForElement.id,String(button.ariaOwnsElements));button.ariaDescribedByElements=[b,a];console.log(button.getAttribute("aria-describedby")===""&&button.ariaDescribedByElements.map(e=>e.id).join(","));button.ariaActiveDescendantElement=null;console.log(button.hasAttribute("aria-activedescendant"),String(button.ariaActiveDescendantElement));const root=host.attachShadow({mode:"open"});root.innerHTML="<span id=inner></span>";const inner=root.getElementById("inner");button.ariaActiveDescendantElement=inner;console.log(String(button.ariaActiveDescendantElement));inner.ariaLabelledByElements=[a];console.log(inner.ariaLabelledByElements.map(e=>e.id).join(","));',
	], runtime, mut messages)
	assert messages == ['a,b b a b null', 'b,a', 'false null', 'null', 'a']
}
