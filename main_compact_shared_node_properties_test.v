module main

import browserjs
import html

fn test_shared_node_properties_preserve_metadata_live_receivers_and_mutations() {
	mut document := html.parse_document('<!doctype html><div id="host">first<!--second--></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.first=host.firstChild;globalThis.second=host.lastChild;
if(first.nodeType!==3||first.nodeName!=="#text"||second.nodeType!==8||second.nodeName!=="#comment")throw new Error("metadata");
for(const node of [first,second]){
 for(const name of ["__state","nodeType","nodeName"]){
  const descriptor=Object.getOwnPropertyDescriptor(node,name);
  if(!descriptor||descriptor.writable||descriptor.enumerable||descriptor.configurable)throw new Error("metadata descriptor "+name);
 }
 const names=Object.getOwnPropertyNames(node);
 if(names.slice(0,5).join(",")!=="__state,nodeType,nodeName,ownerDocument,contains")throw new Error("property order");
 const data=Object.getOwnPropertyDescriptor(node,"data"),value=Object.getOwnPropertyDescriptor(node,"nodeValue");
 if(!data.get||!data.set||data.configurable||data.enumerable||data.get.name!=="read"||data.get.length!==0||value.configurable||value.enumerable)throw new Error("character descriptors");
 if(node.appendChild.name!=="appendChild"||node.appendChild.length!==1||node.ownerDocument!==document||!node.isConnected)throw new Error("method or ownership");
}
const data=Object.getOwnPropertyDescriptor(first,"data");
if(data.get.call(second)!=="second")throw new Error("borrowed receiver");
first.data="updated😀";second.nodeValue=null;
if(first.nodeValue!=="updated😀"||first.length!==9||second.data!==""||host.textContent!=="updated😀")throw new Error("live mutation");
let converted=0;
try{data.set.call({}, {toString(){converted++;return "bad";}});throw new Error("missing receiver error");}catch(error){if(!(error instanceof TypeError))throw error;}
try{data.get.call(Object.create(first));throw new Error("missing inherited receiver error");}catch(error){if(!(error instanceof TypeError))throw error;}
if(converted!==0)throw new Error("conversion before receiver check");
const fragment=document.createDocumentFragment(),copy=first.cloneNode(true);
fragment.appendChild(copy);
if(fragment.firstChild!==copy||fragment.querySelector("span")!==null||fragment.querySelectorAll("span").length!==0)throw new Error("fragment methods");
host.appendChild(fragment);
if(copy.parentNode!==host||second.nextSibling!==copy||copy.previousSibling!==second||copy.data!==first.data)throw new Error("tree mutation");
if(typeof globalThis.__voxSharedNodeWrappers!=="undefined")throw new Error("unexpected diagnostic global");
'], runtime, mut messages)
	assert messages == []string{}
	if !disable_shared_node_properties {
		assert runtime.evaluate_host(r'
Object.getOwnPropertyDescriptor(first,"nodeValue").get===Object.getOwnPropertyDescriptor(second,"nodeValue").get
&&Object.getOwnPropertyDescriptor(first,"data").set===Object.getOwnPropertyDescriptor(second,"data").set
&&first.appendChild===second.appendChild
')! == 'true'
	}
}
