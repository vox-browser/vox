module main

import browserjs
import html

fn test_compact_document_fragment_constructor_uses_native_identity_and_tree_operations() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://pikabu.ru/', [r'
const fragment=new DocumentFragment(),created=document.createDocumentFragment(),detached=document.implementation.createHTMLDocument("").createDocumentFragment();
for(const node of [fragment,created,detached])if(!(node instanceof DocumentFragment)||Object.getPrototypeOf(node)!==DocumentFragment.prototype||Object.prototype.toString.call(node)!=="[object DocumentFragment]"||node.nodeType!==11)throw new Error("fragment constructor identity");
if(fragment.ownerDocument!==document||fragment.parentNode!==null||fragment.isConnected||fragment.childNodes.length!==0||fragment===created||detached.ownerDocument===document)throw new Error("fragment native owner");
const text=document.createTextNode("text"),element=document.createElement("span");element.id="inside";
fragment.appendChild(text);fragment.appendChild(element);
if(fragment.querySelector("#inside")!==element||element.parentNode!==fragment)throw new Error("fragment native query");
const clone=fragment.cloneNode(true);if(!(clone instanceof DocumentFragment)||clone.firstChild===text||clone.textContent!=="text")throw new Error("fragment clone");
host.appendChild(fragment);if(fragment.childNodes.length!==0||host.firstChild!==text||element.parentNode!==host||!element.isConnected)throw new Error("fragment drain");
let rejected=false;try{DocumentFragment();}catch(error){rejected=error instanceof TypeError;}if(!rejected||DocumentFragment.length!==0)throw new Error("fragment constructor validation");
globalThis.fragmentConstructorPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('fragmentConstructorPassed')! == 'true'
}
