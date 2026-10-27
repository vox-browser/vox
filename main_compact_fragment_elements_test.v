module main

import browserjs
import html

fn test_compact_fragment_element_accessors_follow_template_parsing_and_live_mutations() {
	mut document := html.parse_document('<!doctype html><main id="host"></main>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://fragment.test/', [r'
const template=document.createElement("template"),fragment=template.content,children=fragment.children;
if(children!==fragment.children||children.length!==0||fragment.firstElementChild!==null||fragment.lastElementChild!==null||fragment.childElementCount!==0)throw new Error("empty fragment");
template.innerHTML="\n<!--leading--><div id=first><i>nested</i></div>text<span id=last name=label></span><!--trailing-->";
const first=fragment.firstElementChild,last=fragment.lastElementChild;
if(!(first instanceof HTMLElement)||first.id!=="first"||last.id!=="last"||fragment.childElementCount!==2||children.length!==2||children[0]!==first||children.item(1)!==last||children.namedItem("label")!==last||children.first!==first)throw new Error("parsed fragment elements");
if(fragment.firstChild.nodeType!==3||fragment.lastChild.nodeType!==8||Array.from(children).some(node=>node.nodeType!==1))throw new Error("skip non-elements");
const copy=fragment.cloneNode(true);
if(copy.children.length!==2||copy.firstElementChild===first||copy.firstElementChild.innerHTML!=="<i>nested</i>")throw new Error("cloned fragment elements");
fragment.insertBefore(last,first);
if(fragment.firstElementChild!==last||fragment.lastElementChild!==first||children[0]!==last||children.length!==2)throw new Error("reordered live collection");
host.appendChild(fragment);
if(children.length!==0||fragment.childElementCount!==0||fragment.firstElementChild!==null||fragment.lastElementChild!==null||host.children[0]!==last)throw new Error("drained live collection");
const empty=new DocumentFragment(),svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
empty.appendChild(document.createTextNode("text"));empty.appendChild(svg);
if(empty.firstElementChild!==svg||empty.lastElementChild!==svg||empty.children[0]!==svg||empty.childElementCount!==1)throw new Error("SVG child");
for(const name of ["firstElementChild","lastElementChild","children","childElementCount"]){
 const descriptor=Object.getOwnPropertyDescriptor(DocumentFragment.prototype,name);
 if(!descriptor.enumerable||!descriptor.configurable||descriptor.set!==undefined)throw new Error("fragment descriptor");
 for(const receiver of [null,{},document,host]){let rejected=false;try{descriptor.get.call(receiver);}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("fragment brand");}
}
globalThis.fragmentElementsPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('fragmentElementsPassed')! == 'true'
}
