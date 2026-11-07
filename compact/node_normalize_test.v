module main

import browserjs
import html

fn test_compact_node_normalize_merges_and_removes_text_nodes() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(typeof Node.prototype.normalize!=="function"||Object.prototype.hasOwnProperty.call(host,"normalize"))throw new Error("normalize is not a Node method");
host.appendChild(document.createTextNode("a"));
host.appendChild(document.createTextNode(""));
host.appendChild(document.createTextNode("b"));
const span=document.createElement("span");
span.appendChild(document.createTextNode("c"));span.appendChild(document.createTextNode("d"));
host.appendChild(span);
if(host.childNodes.length!==4)throw new Error("setup "+host.childNodes.length);
host.normalize();
if(host.childNodes.length!==2||host.firstChild.data!=="ab"||span.childNodes.length!==1||span.firstChild.data!=="cd")throw new Error("normalize result "+host.childNodes.length+" "+span.childNodes.length);
const detached=document.createElement("p");
detached.appendChild(document.createTextNode("x"));detached.appendChild(document.createTextNode("y"));
detached.normalize();
if(detached.childNodes.length!==1||detached.textContent!=="xy")throw new Error("detached normalize");
document.normalize();
console.log("normalize passed");
'], runtime, mut messages)
	assert messages == ['normalize passed']
}
