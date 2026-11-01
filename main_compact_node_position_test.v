module main

import browserjs
import html

fn test_compact_node_position_tracks_live_order_and_detached_nodes() {
	mut document := html.parse_document('<!doctype html><div id="host">text<span id="child"></span><!--tail--></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://node-position.test/', [r'
const compare=Node.prototype.compareDocumentPosition;
function position(a,b,value){if(compare.call(a,b)!==value)throw new Error("position "+a.nodeName+"/"+b.nodeName+": "+compare.call(a,b)+" != "+value);}
position(host,host,0);position(host,child,20);position(child,host,10);
position(host,other,4);position(other,host,2);
position(host.firstChild,child,4);position(host.lastChild,child,2);
position(document,document.doctype,20);position(document.doctype,document,10);
position(document.doctype,document.documentElement,4);
host.insertBefore(other,host.firstChild);position(other,child,4);position(host,other,20);
host.appendChild(other);position(other,child,2);
const fragment=document.createDocumentFragment(),text=document.createTextNode("new"),comment=document.createComment("new");
fragment.append(text,comment);position(fragment,text,20);position(text,comment,4);
host.appendChild(fragment);position(host,text,20);position(other,text,4);
for(const node of [fragment,document.createElement("aside"),new Image(),document.implementation.createHTMLDocument("")]){
 position(node,node,0);const value=compare.call(host,node);
 if((value&33)!==33||!(value&6)||(value&6)===6||compare.call(host,node)!==value)throw new Error("disconnected order");
}
const editor=document.createElement("textarea");host.append(editor);
// The current ChatGPT runtime retrieves this function from Node.prototype.
if(Node.prototype.compareDocumentPosition.call(host,editor)!==20)throw new Error("prototype call");
console.log("node position passed");
'], runtime, mut messages)
	assert messages == ['node position passed']
}

fn test_compact_node_position_uses_node_brands_without_author_conversion() {
	mut document := html.parse_document('<!doctype html><p id="host">text</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://node-position.test/', [r'
const method=Node.prototype.compareDocumentPosition,d=Object.getOwnPropertyDescriptor(Node.prototype,"compareDocumentPosition");
if(method.name!=="compareDocumentPosition"||method.length!==1||"prototype" in method||!d.writable||!d.enumerable||!d.configurable)throw new Error("descriptor");
function rejects(callback){let rejected=false;try{callback()}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("TypeError required");}
let hooks=0;const fake={get __state(){hooks++;throw new Error("state")},valueOf(){hooks++;throw new Error("conversion")}},proxy=new Proxy(host,{get(){hooks++;throw new Error("get")},getPrototypeOf(){hooks++;throw new Error("prototype")}});
for(const value of [null,undefined,false,1,"node",Symbol(),1n,{},fake,proxy,Object.create(host)]){
 rejects(()=>method.call(value,host));rejects(()=>method.call(host,value));
}
rejects(()=>method.call(host));rejects(()=>new method(host));
if(hooks||method.call(host,host)!==0||method.call(host,host.firstChild)!==20)throw new Error("native identity");
console.log("node position brands passed");
'], runtime, mut messages)
	assert messages == ['node position brands passed']
}
