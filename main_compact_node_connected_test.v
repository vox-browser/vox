module main

import browserjs
import html

fn test_compact_node_connected_tracks_native_insertion_removal_and_fragment_moves() {
	mut document := html.parse_document('<!doctype html><div id="host">text<span id="child"></span><!--tail--></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const text=host.firstChild,comment=host.lastChild,doctype=document.childNodes[0];
for(const node of [document,document.documentElement,host,child,text,comment,doctype])if(node.isConnected!==true)throw new Error("connected parser node");
const fragment=document.createDocumentFragment(),saved=document.createTextNode("detached"),copy=child.cloneNode(true);
fragment.appendChild(saved);fragment.appendChild(copy);
for(const node of [fragment,saved,copy])if(node.isConnected!==false)throw new Error("detached fragment tree");
host.appendChild(fragment);
if(fragment.isConnected!==false||saved.isConnected!==true||copy.isConnected!==true)throw new Error("fragment insertion");
host.removeChild(child);
if(child.isConnected!==false||host.isConnected!==true)throw new Error("pending child removal");
host.appendChild(child);host.remove();
for(const node of [host,child,text,comment,saved,copy])if(node.isConnected!==false)throw new Error("removed subtree");
document.body.appendChild(host);
for(const node of [host,child,text,comment,saved,copy])if(node.isConnected!==true)throw new Error("reattached subtree");
// The Yandex marker layer uses this guard to avoid moving an existing marker.
host.insertBefore(child,copy);
const order=host.childNodes.length;
child.isConnected||host.appendChild(child);
if(host.childNodes.length!==order||host.lastChild!==copy)throw new Error("marker connectivity guard");
child.isConnected&&host.removeChild(child);
if(child.isConnected!==false)throw new Error("marker removal guard");
console.log("native connection passed");
'], runtime, mut messages)
	assert messages == ['native connection passed']
}

fn test_compact_node_connected_getter_brands_nodes_without_author_hooks() {
	mut document := html.parse_document('<!doctype html><div id="host">text</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"isConnected"),get=descriptor.get;
if(get.name!=="get isConnected"||get.length!==0||"prototype" in get||descriptor.set!==undefined||!descriptor.enumerable||!descriptor.configurable)throw new Error("connection descriptor");
function typeError(callback){let threw=false;try{callback()}catch(error){threw=error instanceof TypeError}if(!threw)throw new Error("expected TypeError");}
let hooks=0;const fake={get __state(){hooks++;throw new Error("state")}},proxy=new Proxy(host,{get(){hooks++;throw new Error("proxy get")},getPrototypeOf(){hooks++;throw new Error("proxy prototype")}});
for(const receiver of [null,undefined,false,1,"node",Symbol(),1n,{},fake,proxy,Object.create(host)])typeError(()=>get.call(receiver));
typeError(()=>new get());
if(hooks||get.call(host)!==true||get.call(host.firstChild)!==true||get.call(document)!==true)throw new Error("native connection brand");
const fragment=document.createDocumentFragment();if(get.call(fragment)!==false)throw new Error("fragment brand");
typeError(()=>{ "use strict";host.isConnected=false;});
if(host.isConnected!==true)throw new Error("read-only connection");
console.log("connection conversion passed");
'], runtime, mut messages)
	assert messages == ['connection conversion passed']
}
