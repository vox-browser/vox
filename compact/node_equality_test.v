module main

import browserjs
import html

fn test_compact_is_equal_node_compares_live_trees_and_detached_owners() {
	mut document := html.parse_document('<!doctype html><style id="sheet" nonce="token">p { color: red }</style><div id="host"><b data-a="1">text</b><!--tail--></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://node-equality.test/', [r'
const style=document.getElementById("sheet"),copy=style.cloneNode(true);
if(!style.isEqualNode(copy)||style===copy)throw new Error("Next.js style comparison");
copy.textContent="p { color: blue }";if(style.isEqualNode(copy))throw new Error("pending text change");
copy.textContent=style.textContent;copy.setAttribute("nonce","other");
if(style.isEqualNode(copy))throw new Error("pending attribute change");
copy.setAttribute("nonce","token");if(!copy.isEqualNode(style))throw new Error("restored style");
const clone=host.cloneNode(true);if(!host.isEqualNode(clone)||host.isEqualNode(host.cloneNode(false)))throw new Error("deep children");
clone.firstChild.setAttribute("data-a","2");if(host.isEqualNode(clone))throw new Error("descendant attribute");
clone.firstChild.setAttribute("data-a","1");clone.lastChild.data="changed";
if(host.isEqualNode(clone))throw new Error("comment data");
const a=document.createElement("i"),b=document.createElement("i");
a.setAttribute("x","1");a.setAttribute("y","2");b.setAttribute("y","2");b.setAttribute("x","1");
if(!a.isEqualNode(b)||a.isEqualNode(document.createElementNS("urn:other","i")))throw new Error("attribute order and namespace");
const text=document.createTextNode("same"),comment=document.createComment("same");
if(!text.isEqualNode(document.createTextNode("same"))||text.isEqualNode(comment))throw new Error("node types");
const fragment=document.createDocumentFragment();fragment.append(text);
if(!fragment.isEqualNode(fragment.cloneNode(true))||fragment.isEqualNode(document.createDocumentFragment()))throw new Error("fragment children");
const one=document.implementation.createHTMLDocument("same"),two=document.implementation.createHTMLDocument("same");
if(!one.isEqualNode(two)||one.isEqualNode(document))throw new Error("detached documents");
two.title="different";if(one.isEqualNode(two))throw new Error("document mutation");
const image=new Image(),nativeImage=document.createElement("img");
if(!image.isEqualNode(nativeImage)||!nativeImage.isEqualNode(image))throw new Error("uninserted compact owner");
for(const node of [document,host,text,comment,fragment,document.doctype,one,image]){
 if(!node.isEqualNode(node)||node.isEqualNode(null)||node.isEqualNode(undefined))throw new Error("identity and null");
}
console.log("node equality passed");
'], runtime, mut messages)
	assert messages == ['node equality passed']
}

fn test_compact_is_equal_node_brands_both_nodes_without_author_hooks() {
	mut document := html.parse_document('<!doctype html><p id="host">text</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const method=Node.prototype.isEqualNode,descriptor=Object.getOwnPropertyDescriptor(Node.prototype,"isEqualNode");
if(method.name!=="isEqualNode"||method.length!==1||"prototype" in method||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("method descriptor");
function typeError(callback){let threw=false;try{callback()}catch(error){threw=error instanceof TypeError}if(!threw)throw new Error("expected TypeError");}
let hooks=0;const fake={get __state(){hooks++;throw new Error("state")},valueOf(){hooks++;throw new Error("conversion")}},proxy=new Proxy(host,{get(){hooks++;throw new Error("proxy get")},getPrototypeOf(){hooks++;throw new Error("proxy prototype")}});
for(const receiver of [null,undefined,{},fake,proxy,Object.create(host)])typeError(()=>method.call(receiver,null));
for(const argument of [false,1,"node",Symbol(),1n,{},fake,proxy,Object.create(host)])typeError(()=>method.call(host,argument));
typeError(()=>method.call(host));typeError(()=>new method(host));
if(hooks||!method.call(host,host)||method.call(document,host))throw new Error("native brands");
console.log("node equality conversion passed");
'], runtime, mut messages)
	assert messages == ['node equality conversion passed']
}
