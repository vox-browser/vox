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
if(Object.prototype.toString.call(frame)!=="[object HTMLIFrameElement]"||Object.prototype.toString.call(host)!=="[object HTMLDivElement]")throw new Error("interface tags");
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

fn test_compact_startup_interfaces_preserve_type_checks_and_html_namespaces() {
	mut document := html.parse_document('<!doctype html><link id="sheet" rel="stylesheet"><script id="bootstrap" type="application/json">{}</script><button id="button"></button><form id="form"></form><dialog id="dialog"></dialog><textarea id="editor"></textarea>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
for(const [tag,name,id] of [["link","HTMLLinkElement","sheet"],["script","HTMLScriptElement","bootstrap"],["button","HTMLButtonElement","button"],["form","HTMLFormElement","form"],["dialog","HTMLDialogElement","dialog"],["textarea","HTMLTextAreaElement","editor"]]){
 const Constructor=globalThis[name],parsed=document.getElementById(id),created=document.createElement(tag);
 if(!(parsed instanceof Constructor)||!(created instanceof Constructor)||!(parsed instanceof HTMLElement)||!(parsed instanceof Element)||!(parsed instanceof Node))throw new Error(name+" identity");
 if(Object.getPrototypeOf(Constructor)!==HTMLElement||Object.getPrototypeOf(Constructor.prototype)!==HTMLElement.prototype)throw new Error(name+" inheritance");
 if(Object.prototype.toString.call(parsed)!=="[object "+name+"]"||Constructor.prototype.constructor!==Constructor)throw new Error(name+" prototype");
 if(document.createElementNS("http://www.w3.org/2000/svg",tag) instanceof Constructor||document.createElementNS("urn:test",tag) instanceof Constructor)throw new Error(name+" namespace");
 if(document.createElement("div") instanceof Constructor)throw new Error(name+" unrelated element");
 let illegal=false;try{new Constructor()}catch(error){illegal=error instanceof TypeError;}
 if(!illegal)throw new Error(name+" constructor");
}
if(sheet.rel!=="stylesheet"||bootstrap.type!=="application/json")throw new Error("reflected startup attributes");
'], runtime, mut messages)
	assert messages == []string{}
}

// GitHub's React router checks links and headings with instanceof; every
// element in the HTML index gets its interface.
fn test_compact_html_element_index_interfaces() {
	mut document := html.parse_document('<!doctype html><h2 id="heading">t</h2><a id="link" href="/x">x</a><table><tbody><tr><td id="cell">c</td></tr></tbody></table><custom-tag id="custom"></custom-tag><blink id="unknown"></blink>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
for(const [tag,name] of [["a","HTMLAnchorElement"],["h1","HTMLHeadingElement"],["h6","HTMLHeadingElement"],["p","HTMLParagraphElement"],["span","HTMLSpanElement"],["div","HTMLDivElement"],["ul","HTMLUListElement"],["ol","HTMLOListElement"],["li","HTMLLIElement"],["td","HTMLTableCellElement"],["th","HTMLTableCellElement"],["tr","HTMLTableRowElement"],["tbody","HTMLTableSectionElement"],["table","HTMLTableElement"],["label","HTMLLabelElement"],["option","HTMLOptionElement"],["pre","HTMLPreElement"],["blockquote","HTMLQuoteElement"],["canvas","HTMLCanvasElement"],["details","HTMLDetailsElement"],["slot","HTMLSlotElement"],["style","HTMLStyleElement"],["body","HTMLBodyElement"]]){
 const Constructor=globalThis[name],created=document.createElement(tag);
 if(typeof Constructor!=="function"||!(created instanceof Constructor)||!(created instanceof HTMLElement)||Object.getPrototypeOf(Constructor.prototype)!==HTMLElement.prototype)throw new Error(tag+" "+name);
 if(Object.prototype.toString.call(created)!=="[object "+name+"]"||Constructor.prototype.constructor!==Constructor)throw new Error(name+" prototype");
 if(document.createElementNS("http://www.w3.org/2000/svg",tag) instanceof Constructor)throw new Error(name+" namespace");
 let illegal=false;try{new Constructor()}catch(error){illegal=error instanceof TypeError}if(!illegal)throw new Error(name+" constructor");
}
if(!(heading instanceof HTMLHeadingElement)||!(link instanceof HTMLAnchorElement)||!(cell instanceof HTMLTableCellElement)||!(unknown instanceof HTMLUnknownElement))throw new Error("parsed interfaces");
if(Object.getPrototypeOf(custom)!==HTMLElement.prototype||link instanceof HTMLHeadingElement)throw new Error("custom and unrelated");
'], runtime, mut messages)
	assert messages == []string{}
}
