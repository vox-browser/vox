module main

import browserjs
import dom
import html

fn test_compact_meta_interface_preserves_native_identity_across_creation_and_cloning() {
	address := dom.URL{value: 'https://meta-interface.test/'}
	mut document := html.parse_navigation_document('<!doctype html><meta id="parsed" name="visitor-payload" content="original"><div id="host"></div>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
 if(!(parsed instanceof HTMLMetaElement)||!(parsed instanceof HTMLElement)||!(parsed instanceof Element)||!(parsed instanceof Node))throw Error("parsed meta interface");
 if(Object.getPrototypeOf(HTMLMetaElement)!==HTMLElement||Object.getPrototypeOf(HTMLMetaElement.prototype)!==HTMLElement.prototype||HTMLMetaElement.prototype.constructor!==HTMLMetaElement||Object.prototype.toString.call(parsed)!=="[object HTMLMetaElement]")throw Error("meta hierarchy");
 const created=document.createElement("META"),prefixed=document.createElementNS("http://www.w3.org/1999/xhtml","p:meta"),clone=parsed.cloneNode(true),detached=document.implementation.createHTMLDocument("").createElement("meta");
 for(const element of [created,prefixed,clone,detached])if(!(element instanceof HTMLMetaElement)||!(element instanceof HTMLElement))throw Error("created meta interface");
 if(clone.name!=="visitor-payload"||clone.content!=="original"||prefixed.localName!=="meta"||prefixed.prefix!=="p")throw Error("existing reflection or namespace");
 created.name="visitor-hmac";created.content="changed";created.id="created-meta";host.appendChild(created);
 if(document.getElementById("created-meta")!==created||created.getAttribute("name")!=="visitor-hmac"||created.getAttribute("content")!=="changed")throw Error("native owner/reflection");
 for(const element of [host,document.createElementNS("http://www.w3.org/2000/svg","meta"),document.createElementNS("urn:test","meta"),document.createElementNS("http://www.w3.org/1999/xhtml","META")])if(element instanceof HTMLMetaElement)throw Error("meta namespace/local name classification");
 const shadow=host.attachShadow({mode:"open"});shadow.innerHTML="<meta name=selected-link content=shadow>";
 if(!(shadow.firstChild instanceof HTMLMetaElement))throw Error("shadow meta interface");
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
	created := document.get_element_by_id('created-meta')?
	assert created.as_node().is_html_meta_element()
	assert created.get_attribute_value('content') == 'changed'
	wrapper := runtime.evaluate_host_value('document.getElementById("created-meta")')!
	defer { runtime.release_javascript_value(wrapper) }
	assert voidptr(runtime.native_event_target(wrapper)!) == voidptr(created)
}

fn test_compact_meta_interface_uses_native_html_constructor_validation() {
	address := dom.URL{value: 'https://meta-interface.test/'}
	mut document := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
 const descriptor=Object.getOwnPropertyDescriptor(globalThis,"HTMLMetaElement"),prototype=Object.getOwnPropertyDescriptor(HTMLMetaElement,"prototype");
 if(!descriptor.writable||!descriptor.configurable||descriptor.enumerable||prototype.writable)throw Error("interface descriptors");
 let rejected=0;class Unregistered extends HTMLMetaElement{};
 for(const action of [()=>HTMLMetaElement(),()=>new HTMLMetaElement(),()=>new Unregistered()])try{action()}catch(error){if(error instanceof TypeError)rejected++}
 if(rejected!==3)throw Error("illegal meta constructors");
 class Meta extends HTMLMetaElement{constructor(){super();this.initialized=true}}
 customElements.define("x-meta-interface",Meta,{extends:"meta"});
 globalThis.constructedMeta=new Meta();
 if(!(constructedMeta instanceof Meta)||!(constructedMeta instanceof HTMLMetaElement)||constructedMeta.localName!=="meta"||constructedMeta.ownerDocument!==document||!constructedMeta.initialized)throw Error("native meta constructor");
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
	wrapper := runtime.evaluate_host_value('constructedMeta')!
	defer { runtime.release_javascript_value(wrapper) }
	native := unsafe { &dom.Element(runtime.native_event_target(wrapper)!) }
	assert native.as_node().is_html_meta_element()
	assert native.custom_element_is_value()? == 'x-meta-interface'
}
