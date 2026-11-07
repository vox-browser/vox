module main

import browserjs
import html

fn test_compact_toggle_attribute_preserves_force_values_case_and_native_identity() {
	mut document := html.parse_document('<!doctype html><div id="host" data-kept="original"></div><svg id="svg" viewBox="0 0 10 10"></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(document.documentElement.toggleAttribute("data-conversation-gated",false)!==false)throw new Error("initial gating");
if(host.toggleAttribute("data-new")!==true||host.getAttribute("data-new")!=="")throw new Error("add attribute");
if(host.toggleAttribute("data-new",undefined)!==false||host.hasAttribute("data-new"))throw new Error("undefined means omitted force");
if(host.toggleAttribute("data-kept",true)!==true||host.getAttribute("data-kept")!=="original")throw new Error("preserve forced value");
if(host.toggleAttribute("data-absent",false)!==false||host.hasAttribute("data-absent"))throw new Error("forced absence");
if(host.toggleAttribute("DATA-UPPER",true)!==true||host.getAttribute("data-upper")!=="")throw new Error("HTML ASCII case");
if(!host.toggleAttribute("İ",true)||host.getAttribute("İ")!==""||host.getAttributeNames().includes("i\u0307"))throw new Error("HTML non-ASCII case");
if(svg.toggleAttribute("viewBox",true)!==true||svg.getAttribute("viewBox")!=="0 0 10 10")throw new Error("SVG value");
if(svg.toggleAttribute("viewBox")!==false||svg.hasAttribute("viewBox"))throw new Error("SVG removal");
if(!svg.toggleAttribute("viewBox")||svg.getAttribute("viewBox")!==""||svg.hasAttribute("viewbox"))throw new Error("SVG case");
if(!host.toggleAttribute("data-object",{valueOf(){throw new Error("boolean coercion must not invoke valueOf")}}))throw new Error("truthy force");
if(host.toggleAttribute("data-object",null)!==false)throw new Error("null force");
host.matches("[data-upper]");
'], runtime, mut messages)
	assert messages == []string{}
	host := document.get_element_by_id('host') or { panic('missing host') }
	assert host.get_attribute('data-kept') or { 'missing' } == 'original'
	assert host.has_attribute('data-upper')
	assert host.has_attribute('İ')
	assert !host.has_attribute('i̇')
	assert !host.has_attribute('data-new')
	assert !host.has_attribute('data-object')
}

fn test_compact_toggle_attribute_validates_receivers_arguments_and_names() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const toggle=Element.prototype.toggleAttribute,descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"toggleAttribute");
if(toggle.length!==1||toggle.name!=="toggleAttribute"||!descriptor.enumerable||!descriptor.configurable||!descriptor.writable)throw new Error("toggle descriptor");
for(const receiver of [null,{},document]){let rejected=false;try{toggle.call(receiver,"x")}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("toggle receiver");}
for(const args of [[],[Symbol("name")]]){let rejected=false;try{toggle.apply(host,args)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("toggle arguments");}
for(const name of ["","bad name","bad/name","bad=name","bad>name","bad\u0000name"]){let rejected=false;try{host.toggleAttribute(name)}catch(error){rejected=error instanceof DOMException&&error.name==="InvalidCharacterError"}if(!rejected)throw new Error("invalid attribute name");}
let converted=0;
if(!host.toggleAttribute({toString(){converted++;return "data-converted"}},true)||converted!==1)throw new Error("DOMString conversion");
'], runtime, mut messages)
	assert messages == []string{}
}
