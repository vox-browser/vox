module main

import browserjs
import dom
import html

fn compact_scrollend_fixture(source string) !(&dom.Document, &browserjs.Runtime) {
	mut document := html.parse_document('<!doctype html><div id="scroller"></div>')
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, 'https://scrollend.example.test/', [source], runtime, mut messages)
	assert messages == []string{}
	return document, runtime
}

fn test_compact_scrollend_descriptors_brands_and_detached_document_ownership() {
	mut document, mut runtime := compact_scrollend_fixture(r'
const detached=document.implementation.createHTMLDocument("Detached"),element=document.createElement("div");
const descriptor=Object.getOwnPropertyDescriptor(Document.prototype,"onscrollend");
if(!descriptor||!descriptor.enumerable||!descriptor.configurable||descriptor.get.name!=="get onscrollend"||descriptor.set.name!=="set onscrollend"||descriptor.get.length!==0||descriptor.set.length!==1)throw new Error("Document scrollend descriptor");
if(![descriptor.get,descriptor.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))throw new Error("native scrollend accessors");
if(document.onscrollend!==null||detached.onscrollend!==null||element.onscrollend!==null)throw new Error("scrollend defaults");
for(const target of [null,undefined,{},element,new EventTarget(),Object.create(document),new Proxy(document,{})])for(const invoke of [()=>descriptor.get.call(target),()=>descriptor.set.call(target,()=>{})]){let rejected=false;try{invoke()}catch(e){rejected=e instanceof TypeError}if(!rejected)throw new Error("Document scrollend brand");}
let detachedCalls=0;const handler=function(event){if(this!==detached||event.target!==detached||event.currentTarget!==detached)throw new Error("detached identity");detachedCalls++};
detached.onscrollend=handler;if(detached.onscrollend!==handler||document.onscrollend!==null)throw new Error("independent Document handler");
detached.dispatchEvent(new Event("scrollend"));if(detachedCalls!==1)throw new Error("detached native delivery");
for(const value of [undefined,null,0,false,"source",Symbol(),1n]){detached.onscrollend=value;if(detached.onscrollend!==null)throw new Error("legacy null conversion");}
for(const element of [document.createElement("div"),document.createElementNS("http://www.w3.org/2000/svg","svg"),document.createElementNS("http://www.w3.org/1998/Math/MathML","math")]){const fn=()=>{};element.onscrollend=fn;if(element.onscrollend!==fn)throw new Error("Element scrollend identity");}
globalThis.scrollendDescriptorPassed=true;
')!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host('scrollendDescriptorPassed')! == 'true'
}

fn test_compact_scrollend_uses_native_pending_scroll_events_and_listener_order() {
	mut document, mut runtime := compact_scrollend_fixture(r'
globalThis.scrollEndOrder=[];
document.addEventListener("scrollend",event=>{if(event.target!==document||event.currentTarget!==document||!event.bubbles)throw new Error("Document scrollend event");scrollEndOrder.push("before")});
document.onscrollend=()=>scrollEndOrder.push("old");document.addEventListener("scrollend",()=>scrollEndOrder.push("after"));
document.onscrollend=function(event){if(this!==document||window.event!==event)throw new Error("Document callback context");scrollEndOrder.push("handler")};
scroller.addEventListener("scrollend",()=>scrollEndOrder.push("element-before"));
scroller.onscrollend=function(event){if(this!==scroller||event.target!==scroller||event.currentTarget!==scroller||event.bubbles)throw new Error("Element scrollend event");scrollEndOrder.push("element-handler")};
scroller.addEventListener("scrollend",()=>scrollEndOrder.push("element-after"));
')!
	defer { runtime.close(); document.finalize() }
	target := document.get_element_by_id('scroller') or { panic('missing scroller') }
	assert document.append_pending_scroll_event(dom.PendingScrollEvent{target: document.as_node(), type_: 'scrollend'})
	assert !document.append_pending_scroll_event(dom.PendingScrollEvent{target: document.as_node(), type_: 'scrollend'})
	assert document.append_pending_scroll_event(dom.PendingScrollEvent{target: target.as_node(), type_: 'scrollend'})
	document.run_the_scroll_steps()
	order := runtime.evaluate_host('scrollEndOrder.join(",")')!
	assert order == 'before,handler,after,element-before,element-handler,element-after'
	assert runtime.evaluate_host('window.event===undefined')! == 'true'
	runtime.evaluate_host('document.onscrollend=null;scroller.onscrollend=null;scrollEndOrder.length=0;0')!
	assert document.append_pending_scroll_event(dom.PendingScrollEvent{target: target.as_node(), type_: 'scrollend'})
	document.run_the_scroll_steps()
	assert runtime.evaluate_host('scrollEndOrder.join(",")')! == 'element-before,element-after'
}

fn test_compact_element_scrollend_raw_handler_compiles_and_cancels_normally() {
	mut document, mut runtime := compact_scrollend_fixture(r'
globalThis.rawScrollEnds=0;const source="globalThis.rawScrollEnds++;return false";scroller.setAttribute("onscrollend",source);
if(typeof scroller.onscrollend!=="function"||scroller.onscrollend.name!=="onscrollend")throw new Error("raw scrollend compilation");
if(scroller.dispatchEvent(new Event("scrollend",{cancelable:true}))!==false||rawScrollEnds!==1)throw new Error("raw scrollend cancellation");
const first=scroller.onscrollend;scroller.onscrollend=()=>{throw new Error("stale IDL handler")};scroller.setAttribute("onscrollend",source);if(scroller.onscrollend===first||scroller.dispatchEvent(new Event("scrollend",{cancelable:true}))!==false||rawScrollEnds!==2)throw new Error("equal-text handler replacement");
scroller.removeAttribute("onscrollend");if(scroller.onscrollend!==null)throw new Error("content handler removal");if(!scroller.dispatchEvent(new Event("scrollend",{cancelable:true}))||rawScrollEnds!==2)throw new Error("raw scrollend removal");
globalThis.rawScrollEndPassed=true;
')!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host('rawScrollEndPassed')! == 'true'
}
