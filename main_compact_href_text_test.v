module main

import browserjs
import html

fn test_href_text_bindings_preserve_native_urls_pending_writes_and_foreign_owners() {
	mut document := html.parse_document('<!doctype html><body><a id="anchor" href="../first?x=1#part"></a><area id="area" href="https://EXAMPLE.test:443/a"></area><link id="link" href="style.css"><base id="base" href="assets/"></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://page.test/a/b', [r'
const expected=["https://page.test/first?x=1#part","https://example.test/a","https://page.test/a/style.css","https://page.test/a/assets/"];
for(const [index,id]of["anchor","area","link","base"].entries()){const element=document.getElementById(id);if(element.href!==expected[index]||element.href!==expected[index])throw new Error("href "+id+" "+element.href);}
const anchor=document.getElementById("anchor");anchor.href="next";if(anchor.href!==new URL("next",location.href).href)throw new Error("pending href");
anchor.removeAttribute("href");if(anchor.href!=="")throw new Error("missing href");
anchor.href="http://[invalid";if(anchor.href!=="http://[invalid")throw new Error("invalid href");
const other=document.implementation.createHTMLDocument("other");const foreignBase=other.createElement("base");foreignBase.href="https://foreign.test/root/";other.head.appendChild(foreignBase);
anchor.href="child";other.body.appendChild(anchor);if(anchor.href!=="https://foreign.test/root/child")throw new Error("foreign href");
document.body.appendChild(anchor);if(anchor.href!==new URL("child",location.href).href)throw new Error("returned href");
globalThis.hrefTextPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('hrefTextPassed')! == 'true'
}

fn test_href_text_bindings_preserve_author_constructor_getter_and_base_coercion_order() {
	mut document := html.parse_document('<!doctype html><body><a id="anchor" href="child"></a></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://page.test/a/b', [r'
const anchor=document.getElementById("anchor"),original=URL,descriptor=Object.getOwnPropertyDescriptor(URL.prototype,"href"),events=[];
globalThis.URL=function(value,base){events.push(value,base);this.href="custom";};
if(anchor.href!=="custom"||events.join(",")!=="child,https://page.test/a/b")throw new Error("custom constructor");
globalThis.URL=original;
Object.defineProperty(original.prototype,"href",{get(){return "custom getter";},configurable:true});
if(anchor.href!=="custom getter")throw new Error("custom getter");
Object.defineProperty(original.prototype,"href",{value:"custom value",configurable:true});
if(anchor.href!=="custom value")throw new Error("custom value");
Object.defineProperty(original.prototype,"href",descriptor);
let reads=0;Object.defineProperty(globalThis,"URL",{get(){reads++;return original;},configurable:true});
if(anchor.href!=="https://page.test/a/child"||reads!==1)throw new Error("constructor read count");
Object.defineProperty(globalThis,"URL",{value:original,writable:true,configurable:true});
globalThis.hrefAuthorPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('hrefAuthorPassed')! == 'true'
}
