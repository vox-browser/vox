module main

import browserjs
import html

// Ladybird a77aced1a001b62604dc39474fe658f06ad124c4.
fn test_compact_large_named_node_map_keeps_duplicate_and_uppercase_name_rules() {
	mut document := html.parse_document('<!doctype html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const element=document.createElement("div");
for(let i=0;i<3000;i++)element.setAttribute("data-"+i,String(i));
element.setAttributeNS(null,"Uppercase","hidden");
element.setAttributeNS("urn:a","duplicate","first");
element.setAttributeNS("urn:b","duplicate","second");
const attributes=element.attributes,names=Object.getOwnPropertyNames(attributes);
if(attributes.length!==3003||names.length!==6004)throw new Error("enumeration length");
if(names[0]!=="0"||names[3002]!=="3002"||names[3003]!=="data-0"||names[names.length-1]!=="duplicate")throw new Error("enumeration order");
if(names.includes("Uppercase")||names.filter(name=>name==="duplicate").length!==1)throw new Error("named property filtering");
if(!("data-1234" in attributes)||"missing" in attributes||"Uppercase" in attributes||"uppercase" in attributes)throw new Error("supported names");
if(attributes.duplicate.value!=="first")throw new Error("first duplicate wins");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_attributes_support_jquery_option_value_hook() {
	mut document := html.parse_document('<!doctype html><select id="filter"><option value="standart">По бампам</option><option value="timestamp">По времени</option><option>Text only</option></select>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
// jQuery 1.8 valHooks.option.get and valHooks.select.set (2ch.su catalog filter).
const optionValue=function(a){var b=a.attributes.value;return!b||b.specified?a.value:a.text};
const options=filter.querySelectorAll("option");
if(options.length!==3)throw new Error("options");
if(optionValue(options[0])!=="standart"||optionValue(options[1])!=="timestamp")throw new Error("value attribute");
if(options[2].attributes.value!==undefined||optionValue(options[2])!=="Text only")throw new Error("missing value attribute");
for(const option of options)option.selected=optionValue(option)==="timestamp";
if(filter.value!=="timestamp")throw new Error("select value");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_attributes_are_a_live_same_object_named_node_map() {
	mut document := html.parse_document('<!doctype html><div id="host" class="card" data-num="12" title="t"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const attributes=host.attributes;
if(attributes!==host.attributes||!(attributes instanceof NamedNodeMap)||Object.prototype.toString.call(attributes)!=="[object NamedNodeMap]")throw new Error("same object");
if(attributes.length!==4||JSON.stringify([...attributes].map(a=>a.name))!==JSON.stringify(["id","class","data-num","title"]))throw new Error("order");
const num=attributes["data-num"];
if(!(num instanceof Attr)||!(num instanceof Node)||num.nodeType!==2||num.nodeName!=="data-num"||num.localName!=="data-num"||num.prefix!==null||num.namespaceURI!==null)throw new Error("attr fields");
if(num.value!=="12"||!num.specified||num.ownerElement!==host||num.ownerDocument!==document)throw new Error("attr value");
if(attributes.getNamedItem("DATA-NUM")!==num||attributes.item(2)!==num||attributes[2]!==num||host.getAttributeNode("data-num")!==num)throw new Error("identity");
if(attributes.item(4)!==null||attributes[4]!==undefined||attributes.getNamedItem("missing")!==null)throw new Error("missing");
if(JSON.stringify(Object.keys(attributes))!==JSON.stringify(["0","1","2","3"]))throw new Error("named properties are not enumerable");
if(!Object.getOwnPropertyNames(attributes).includes("data-num")||!("title" in attributes)||"missing" in attributes)throw new Error("named properties");
host.setAttribute("data-new","x");
if(attributes.length!==5||attributes[4].name!=="data-new"||attributes["data-new"].value!=="x")throw new Error("live insertion");
num.value="13";
if(host.getAttribute("data-num")!=="13"||attributes["data-num"]!==num)throw new Error("attr write");
host.setAttribute("data-num","14");
if(num.value!=="14")throw new Error("attr reads the current value");
host.removeAttribute("title");
if(attributes.length!==4||"title" in attributes)throw new Error("live removal");
const removed=attributes.removeNamedItem("data-new");
if(removed.ownerElement!==null||removed.value!=="x"||host.hasAttribute("data-new"))throw new Error("removeNamedItem");
let missing=false;try{attributes.removeNamedItem("data-new")}catch(error){missing=error instanceof DOMException&&error.name==="NotFoundError"}
if(!missing)throw new Error("NotFoundError");
if(!host.hasAttributes()||document.createElement("p").hasAttributes())throw new Error("hasAttributes");
host.setAttribute("length","shadowed");
if(attributes.length!==4||typeof attributes.item!=="function"||attributes.getNamedItem("length").value!=="shadowed")throw new Error("prototype members win over names");
let rejected=false;try{"use strict";Object.defineProperty(attributes,"0",{value:1})}catch(error){rejected=error instanceof TypeError}
if(!rejected||attributes[0].name!=="id")throw new Error("indexed properties are read-only");
'], runtime, mut messages)
	assert messages == []string{}
	host := document.get_element_by_id('host') or { panic('missing host') }
	assert host.get_attribute('data-num') or { 'missing' } == '14'
	assert host.get_attribute('length') or { 'missing' } == 'shadowed'
	assert !host.has_attribute('title')
	assert !host.has_attribute('data-new')
}

fn test_compact_attributes_keep_namespaces_and_check_receivers() {
	mut document := html.parse_document('<!doctype html><svg id="svg" viewBox="0 0 10 10"><use id="use" xlink:href="#shape"></use></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const xlink="http://www.w3.org/1999/xlink",href=use.attributes.getNamedItemNS(xlink,"href");
if(!href||href.name!=="xlink:href"||href.prefix!=="xlink"||href.localName!=="href"||href.namespaceURI!==xlink||href.value!=="#shape")throw new Error("namespaced attribute");
if(use.getAttributeNodeNS(xlink,"href")!==href||use.attributes.getNamedItem("xlink:href")!==href)throw new Error("namespaced lookup");
if(!svg.attributes.viewBox||svg.attributes.getNamedItem("viewbox")!==null||svg.attributes.viewBox.value!=="0 0 10 10")throw new Error("SVG names keep case");
const created=document.createElement("a");created.setAttribute("HREF","/x");
if(created.attributes.length!==1||created.attributes[0].name!=="href"||created.attributes.href.ownerElement!==created)throw new Error("created element");
const getter=Object.getOwnPropertyDescriptor(Element.prototype,"attributes").get;
if(getter.name!=="get attributes")throw new Error("getter name");
for(const receiver of [null,{},document]){let failed=false;try{getter.call(receiver)}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("Element receiver");}
for(const [constructor,label] of [[Attr,"Attr"],[NamedNodeMap,"NamedNodeMap"]]){let failed=false;try{new constructor()}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error(label+" constructor");}
let failed=false;try{NamedNodeMap.prototype.item.call({},0)}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("NamedNodeMap receiver");
failed=false;try{Object.getOwnPropertyDescriptor(Attr.prototype,"value").get.call({})}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("Attr receiver");
'], runtime, mut messages)
	assert messages == []string{}
}
