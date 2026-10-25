module main

import browserjs
import html

fn test_compact_html_interfaces_classify_parser_and_script_created_iframes() {
	mut document := html.parse_document('<!doctype html><div id="host"></div><iframe id="frame"></iframe><svg id="svg"><iframe id="foreign"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(!(host instanceof HTMLElement)||!(host instanceof Element)||host instanceof HTMLIFrameElement)throw new Error("HTML element hierarchy");
if(!(frame instanceof HTMLIFrameElement)||!(frame instanceof HTMLElement)||!(frame instanceof Element))throw new Error("iframe hierarchy");
if(Object.getPrototypeOf(HTMLIFrameElement)!==HTMLElement||Object.getPrototypeOf(HTMLIFrameElement.prototype)!==HTMLElement.prototype||Object.getPrototypeOf(HTMLElement.prototype)!==Element.prototype)throw new Error("interface inheritance");
if(Object.prototype.toString.call(frame)!=="[object HTMLIFrameElement]"||Object.prototype.toString.call(host)!=="[object HTMLElement]")throw new Error("interface tags");
if(svg instanceof HTMLElement||foreign instanceof HTMLIFrameElement)throw new Error("namespace classification");
const created=document.createElement("iframe"),other=document.createElementNS("http://www.w3.org/2000/svg","iframe");
if(!(created instanceof HTMLIFrameElement)||other instanceof HTMLIFrameElement)throw new Error("created iframe");
let illegal=0;for(const Constructor of [HTMLElement,HTMLIFrameElement])try{new Constructor()}catch(error){if(error instanceof TypeError)illegal++}
if(illegal!==2)throw new Error("HTML constructors");
// React active-element traversal must accept an ordinary focused element.
let focused=host,owner=window;
while(focused instanceof owner.HTMLIFrameElement)throw new Error("ordinary element treated as iframe");
'], runtime, mut messages)
	assert messages == []string{}
}
