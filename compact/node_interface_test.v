module main

import browserjs
import html

fn test_compact_node_interface_classifies_native_nodes_through_the_common_base() {
	mut document := html.parse_document('<!doctype html><div id="host">text<!--anchor--></div><svg id="drawing"></svg><template id="content"><i></i></template>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://node-interface.test/', [r'
if(Object.getPrototypeOf(Node)!==EventTarget||Object.getPrototypeOf(Node.prototype)!==EventTarget.prototype)throw new Error("Node inheritance");
for(const constructor of [Element,Document,DocumentFragment])if(Object.getPrototypeOf(constructor)!==Node||Object.getPrototypeOf(constructor.prototype)!==Node.prototype)throw new Error("interface inheritance "+constructor.name);
const host=document.getElementById("host"),drawing=document.getElementById("drawing");
const nodes=[document,document.doctype,document.documentElement,host,host.firstChild,host.lastChild,drawing,document.createElement("p"),document.createTextNode("created"),document.createComment("created"),document.createDocumentFragment(),new DocumentFragment(),document.getElementById("content").content,host.cloneNode(true),document.implementation.createHTMLDocument("")];
for(const node of nodes)if(!(node instanceof Node)||!(node instanceof EventTarget))throw new Error("Node classification "+(node&&node.nodeName));
for(const node of [host.firstChild,host.lastChild,document.doctype])if(Object.getPrototypeOf(node)!==Node.prototype)throw new Error("generic node prototype");
for(const value of [{nodeType:1},new EventTarget(),window,document.implementation])if(value instanceof Node)throw new Error("non-node classification");
// Floating UI uses the local Node interface before trying the owning realm.
const isNode=value=>value instanceof Node||value instanceof (value.ownerDocument.defaultView||window).Node;
if(!isNode(host)||!isNode(host.firstChild)||!isNode(drawing))throw new Error("positioning library classification");
let rejected=0;for(const call of [()=>Node(),()=>new Node()])try{call();}catch(error){if(error instanceof TypeError)rejected++;}
if(rejected!==2||Node.length!==0||Object.getOwnPropertyDescriptor(Node,"prototype").writable)throw new Error("Node constructor");
globalThis.nodeInterfacePassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('nodeInterfacePassed')! == 'true'
}

fn test_compact_node_constants_are_inherited_and_readonly() {
	mut document := html.parse_document('<!doctype html><p></p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://node-interface.test/', [r'
const expected={ELEMENT_NODE:1,ATTRIBUTE_NODE:2,TEXT_NODE:3,CDATA_SECTION_NODE:4,ENTITY_REFERENCE_NODE:5,ENTITY_NODE:6,PROCESSING_INSTRUCTION_NODE:7,COMMENT_NODE:8,DOCUMENT_NODE:9,DOCUMENT_TYPE_NODE:10,DOCUMENT_FRAGMENT_NODE:11,NOTATION_NODE:12,DOCUMENT_POSITION_DISCONNECTED:1,DOCUMENT_POSITION_PRECEDING:2,DOCUMENT_POSITION_FOLLOWING:4,DOCUMENT_POSITION_CONTAINS:8,DOCUMENT_POSITION_CONTAINED_BY:16,DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC:32};
for(const [name,value] of Object.entries(expected)){
 for(const target of [Node,Node.prototype]){const descriptor=Object.getOwnPropertyDescriptor(target,name);if(!descriptor||descriptor.value!==value||descriptor.writable||descriptor.configurable||!descriptor.enumerable)throw new Error("constant descriptor "+name);}
 for(const target of [Element,Document,DocumentFragment,document,document.body,document.createTextNode(""),new DocumentFragment()])if(target[name]!==value||Object.hasOwn(target,name))throw new Error("constant inheritance "+name);
}
globalThis.nodeConstantsPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('nodeConstantsPassed')! == 'true'
}
