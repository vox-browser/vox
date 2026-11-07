module main

import browserjs
import html

fn test_compact_contains_tracks_native_identity_and_live_fragment_moves() {
	mut document := html.parse_document('<!doctype html><div id="host">text<span id="child"></span><!--tail--></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const text=host.firstChild,comment=host.lastChild,doctype=document.childNodes[0];
if(!host.contains(host)||!host.contains(child)||!host.contains(text)||!host.contains(comment)||host.contains(other)||child.contains(host)||!text.contains(text)||text.contains(child))throw new Error("inclusive native descendants");
if(!document.contains(host)||!document.contains(document)||!document.contains(doctype)||host.contains(document)||doctype.contains(host))throw new Error("document containment");
const fragment=document.createDocumentFragment(),saved=document.createTextNode("detached"),copy=child.cloneNode(true);
fragment.appendChild(saved);fragment.appendChild(copy);
if(!fragment.contains(saved)||!fragment.contains(copy)||document.contains(saved)||host.contains(copy)||copy.contains(child))throw new Error("detached identity");
host.appendChild(fragment);
if(fragment.contains(saved)||fragment.contains(copy)||!document.contains(saved)||!host.contains(copy)||!fragment.contains(fragment))throw new Error("fragment move");
other.appendChild(child);
if(host.contains(child)||!other.contains(child)||!document.contains(child))throw new Error("pending reparent");
other.removeChild(child);
if(other.contains(child)||document.contains(child)||!child.contains(child))throw new Error("detached child");
for(const node of [document,host,text,comment,fragment,doctype])if(node.contains(null)||node.contains(undefined))throw new Error("nullable Node argument");
console.log("native contains passed");
'], runtime, mut messages)
	assert messages == ['native contains passed']
}

fn test_compact_contains_brands_both_nodes_without_author_hooks() {
	mut document := html.parse_document('<!doctype html><div id="host">text</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const method=host.contains,descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"contains");
if(method.name!=="contains"||method.length!==1||"prototype" in method||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("contains descriptor");
function typeError(callback){let threw=false;try{callback()}catch(error){threw=error instanceof TypeError}if(!threw)throw new Error("expected TypeError");}
let hooks=0;const fake={get __state(){hooks++;throw new Error("state")},valueOf(){hooks++;throw new Error("conversion")}},proxy=new Proxy(host,{get(){hooks++;throw new Error("proxy get")},getPrototypeOf(){hooks++;throw new Error("proxy prototype")}});
for(const receiver of [null,undefined,{},fake,proxy,Object.create(host)])typeError(()=>method.call(receiver,null));
for(const argument of [false,1,"node",Symbol(),1n,{},fake,proxy,Object.create(host)])typeError(()=>method.call(host,argument));
typeError(()=>method.call(host));typeError(()=>new method(host));
if(hooks||!method.call(host,host)||!method.call(host,host.firstChild)||!method.call(document,host))throw new Error("native node brand");
console.log("contains conversion passed");
'], runtime, mut messages)
	assert messages == ['contains conversion passed']
}
