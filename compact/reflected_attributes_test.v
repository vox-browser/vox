module main

import browserjs
import html

fn test_aria_and_html_element_attributes_reflect_their_content_attributes() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="box" role="button" aria-label="Go" dir="RTL" tabindex=" 7x" translate="no"><a id="link" href="#">l</a><span id="inner"></span></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'console.log(box.role,box.ariaLabel,String(box.ariaHidden),box.dir,box.tabIndex,link.tabIndex,inner.tabIndex,inner.translate,link.draggable,inner.draggable,String(box.popover),box.contentEditable);box.ariaHidden="true";box.ariaLabel=null;box.popover="";box.inert=true;console.log(box.getAttribute("aria-hidden"),box.hasAttribute("aria-label"),box.popover,box.hasAttribute("inert"));try{box.contentEditable="maybe"}catch(e){console.log(e.name)}box.contentEditable="PLAINTEXT-ONLY";console.log(box.getAttribute("contenteditable"),box.contentEditable,inner.slot,box.enterKeyHint);const made=document.createElement("p");made.className="x y";console.log(Object.prototype.toString.call(made.classList),made.classList instanceof DOMTokenList,Object.prototype.toString.call(document.body.classList));',
	], runtime, mut messages)
	assert messages == ['button Go null rtl 7 0 -1 false true false null inherit',
		'true false auto true', 'SyntaxError', 'plaintext-only plaintext-only  ', '[object DOMTokenList] true [object DOMTokenList]']
}
