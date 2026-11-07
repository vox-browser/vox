module main

import browserjs
import html

// Wikipedia's portal script reaches the language picker's container through
// select.parentNode.parentNode and inserts its label with parentNode.insertBefore.
fn test_compact_elements_expose_their_parents() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="outer" class="styled-select no-js"><div id="arrow" class="hide-arrow"><select id="language"><option value="en">English</option></select></div></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['
		const select = document.getElementById("language");
		const label = document.createElement("label");
		label.textContent = select.value;
		select.parentNode.parentNode.className = " styled-select js-enabled";
		select.parentNode.insertBefore(label, select);
		globalThis.result = [select.parentElement.id, select.parentNode.parentNode.id,
			label.parentNode.id, document.documentElement.parentNode === document,
			document.documentElement.parentElement === null, select.value].join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'arrow,outer,arrow,true,true,en'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	outer := document.get_element_by_id('outer') or { panic('missing outer') }
	assert outer.get_attribute_value('class') == ' styled-select js-enabled'
	arrow := document.get_element_by_id('arrow') or { panic('missing arrow') }
	first := arrow.as_node().first_child() or { panic('missing label') }
	assert first.as_element()?.local_name() == 'label'
	assert messages == []
}

fn test_compact_class_list_replace_follows_dom_token_list() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><p id="target" class="a no-js b js-enabled"></p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['
		const list = document.getElementById("target").classList;
		globalThis.result = [list.replace("missing", "x"), list.replace("no-js", "js-enabled")].join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'false,true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_state(document, state, runtime.canvas_elements_for_binding(), mut messages)
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_attribute_value('class') == 'a js-enabled b'
}

// Wikipedia's language picker reads select.value for its label and padding.
fn test_compact_select_exposes_its_value() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><select id="a"><option value="en">English</option><option value="de" selected>Deutsch</option></select><select id="b"><option>Plain</option></select><div id="c"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['
		"use strict";
		const a = document.getElementById("a"), b = document.getElementById("b"), c = document.getElementById("c");
		const before = [a.value, b.value, typeof c.value];
		c.value = 7;
		globalThis.result = before.concat([c.value]).join(",");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'de,Plain,undefined,7'
	assert messages == []
}

fn check_compact_parent_script(script string) ! {
	mut document := html.parse_document('<!doctype html><div id="host"><b id="old">old</b></div><div id="other">other</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://vlang.io/', [script,
		'globalThis.parentMutationPassed=true;'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('parentMutationPassed')! == 'true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_parent_node_highlighting_transfers_fragment_children_and_preserves_identity() {
	check_compact_parent_script(r'
const list=host.childNodes,fragment=document.createDocumentFragment(),span=document.createElement("span"),text=document.createTextNode("fn ");
span.className="keyword";span.textContent="main";
if(fragment.append(text,span,"()")!==undefined)throw new Error("append return");
if(fragment.textContent!=="fn main()"||fragment.childNodes[1]!==span)throw new Error("fragment append");
const source=fragment.childNodes;
if(host.replaceChildren(fragment)!==undefined)throw new Error("replaceChildren return");
if(source.length!==0||list.length!==3||list[0]!==text||list[1]!==span||old.parentNode!==null||span.parentNode!==host)throw new Error("fragment transfer");
if(host.innerHTML!=="fn <span class=\"keyword\">main</span>()")throw new Error("highlight markup: "+host.innerHTML);
host.prepend("[",span);host.append("]");
if(host.textContent!=="[mainfn ()]"||span.parentNode!==host)throw new Error("moving append/prepend");
host.replaceChildren();if(list.length!==0||text.parentNode!==null)throw new Error("empty replacement");
')!
}

fn test_compact_parent_node_converts_strings_and_checks_brands_and_hierarchy() {
	check_compact_parent_script(r'
const method=DocumentFragment.prototype.append;
if(method.length!==0||method.name!=="append"||DocumentFragment.prototype[Symbol.unscopables].append!==true)throw new Error("metadata");
let conversions=0;const value={toString(){conversions++;return "value";}};
const fragment=new DocumentFragment();fragment.append(null,undefined,7,true,value);
if(fragment.textContent!=="nullundefined7truevalue"||conversions!==1)throw new Error("DOMString conversion");
for(const receiver of [null,undefined,{},document.createTextNode("text"),new Proxy(fragment,{})]){
 let rejected=false;try{method.call(receiver,value);}catch(error){rejected=error instanceof TypeError;}
 if(!rejected||conversions!==1)throw new Error("receiver before conversion");
}
let rejected=false;try{fragment.append(Symbol());}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("symbol");
rejected=false;try{host.replaceChildren(document);}catch(error){rejected=error instanceof DOMException&&error.name==="HierarchyRequestError";}
if(!rejected||host.firstChild!==old)throw new Error("hierarchy validity");
const detached=document.implementation.createHTMLDocument("other"),node=detached.createElement("em");node.textContent="foreign";
detached.body.append(node);host.replaceChildren(node);
if(node.ownerDocument!==document||node.parentNode!==host||detached.body.childNodes.length!==0||host.textContent!=="foreign")throw new Error("adoption");
')!
}
