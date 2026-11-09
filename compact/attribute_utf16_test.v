module main

import browserjs
import html

fn test_native_attribute_replies_preserve_utf16_units_with_and_without_document_storage() {
	for retained in [false, true] {
		mut document := html.parse_document('<!doctype html><div id="target"></div>')
		if retained { document.enable_native_storage() }
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close(); document.finalize() }
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [], runtime, mut messages)
		mut target := document.get_element_by_id('target') or { panic('missing target') }
		target.set_attribute_value('data-units', [u8(0xed), 0xa0, 0x80, `|`, 0xed, 0xb0, 0x81, `|`, 0, `|`].bytestr() + '😀')
		result := runtime.evaluate_host(r'(()=>{try{
 const target=document.getElementById("target"), expected="\ud800|\udc01|\u0000|😀";
 const check=(actual,label)=>{if(actual!==expected)throw new Error(label+": "+JSON.stringify(actual));};
 check(target.getAttribute("data-units"),"attribute read");
 check(target.getAttributeNode("data-units").value,"Attr read");
 check(target.attributes.getNamedItem("data-units").value,"NamedNodeMap read");
 const detached=target.removeAttributeNode(target.getAttributeNode("data-units"));
 check(detached.value,"detached Attr read");
 detached.value=expected;target.setAttributeNode(detached);check(target.getAttribute("data-units"),"Attr write");
 return "passed";
}catch(error){return String(error);}})()')!
		assert result == 'passed', 'retained=${retained}: ' + result
	}
}

fn test_native_attribute_writes_and_reflections_preserve_domstrings_before_formdata_conversion() {
	mut document := html.parse_document('<!doctype html><form id="form"></form>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	result := runtime.evaluate_host(r'(()=>{try{
 const input=document.createElement("input"), name="field-\ud800-\udc01-\u0000-😀", value="value-\udc01";
 input.name=name;input.value=value;
 const check=(actual,expected,label)=>{if(actual!==expected)throw new Error(label+": "+JSON.stringify(actual));};
 check(input.name,name,"name reflection");check(input.getAttribute("name"),name,"native name");
 check(input.value,value,"input value");
 input.setAttributeNS("urn:units","p:units",name);check(input.getAttributeNS("urn:units","units"),name,"namespaced value");
 input.setAttributeNS("urn:\ud800","p:raw",name);check(input.getAttributeNS("urn:\ud800","raw"),name,"namespace DOMString");
 let conversions=0;input.setAttribute("data-object",{toString(){conversions++;return name;}});
 check(conversions,1,"one conversion");check(input.getAttribute("data-object"),name,"converted value");
 const reason={};let caught;try{input.setAttribute("data-throw",{toString(){throw reason;}});}catch(error){caught=error;}
 if(caught!==reason)throw new Error("conversion exception identity");
 const form=document.getElementById("form");form.appendChild(input);
 const data=new FormData(form);check(data.get("field-�-�-\u0000-😀"),"value-�","scalar form entries");
 check(input.name,name,"name after FormData");check(input.value,value,"value after FormData");
 return "passed";
}catch(error){return String(error);}})()')!
	assert result == 'passed', result
}
