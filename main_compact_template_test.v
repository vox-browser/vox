module main

import browserjs
import html

fn test_compact_template_content_clones_the_inert_native_subtree_and_adopts_on_insertion() {
	mut document := html.parse_document('<!doctype html><template id="source"><b class="label">original</b><!--tail--><template id="nested"><i>nested</i></template></template><main id="host"></main>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://template.test/', [r'
const template=document.getElementById("source"),content=template.content;
if(!(template instanceof HTMLTemplateElement)||!(template instanceof HTMLElement)||content!==template.content||content.nodeType!==11||content.nodeName!=="#document-fragment")throw new Error("template content identity");
if(template.childNodes.length!==0||content.childNodes.length!==3||content.isConnected||content.parentNode!==null||content.ownerDocument===document)throw new Error("inert content tree");
const copy=content.cloneNode(true),label=copy.querySelector(".label"),nested=copy.querySelector("template");
if(copy===content||label===content.firstChild||nested.content===content.querySelector("template").content||nested.content.firstChild.textContent!=="nested")throw new Error("deep content clone");
label.textContent="copy";
host.appendChild(copy);
if(copy.childNodes.length!==0||host.firstChild!==label||label.ownerDocument!==document||!label.isConnected||content.firstChild.textContent!=="original")throw new Error("fragment adoption");
const shallow=template.cloneNode(false),deep=template.cloneNode(true);
if(shallow.content.childNodes.length!==0||deep.content.childNodes.length!==3||deep.content.firstChild===content.firstChild||deep.content.firstChild.textContent!=="original")throw new Error("template clone steps");
globalThis.templateClonePassed=true;
'], runtime, mut messages)
	assert runtime.evaluate_host('templateClonePassed')! == 'true'
	assert messages == []string{}
	host := document.get_element_by_id('host') or { panic('missing host') }
	assert host.as_node().text_content()? == 'copy'
}

fn test_compact_script_created_template_content_is_live_readonly_and_separate_from_meta_content() {
	mut document := html.parse_document('<!doctype html><meta id="meta" content="initial"><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://template.test/', [r'
const template=document.createElement("template"),content=template.content,list=content.childNodes;
if(list.length!==0||template.content!==content)throw new Error("empty detached template");
template.innerHTML="<span class=\"child\">first</span>";
if(template.content!==content||list.length!==1||content.querySelector(".child").textContent!=="first")throw new Error("template innerHTML");
content.firstChild.textContent="updated";
if(template.innerHTML!=="<span class=\"child\">updated</span>")throw new Error("serialize content mutation");
template.setAttribute("content","attribute");
if(template.content!==content||template.getAttribute("content")!=="attribute")throw new Error("content attribute separation");
const descriptor=Object.getOwnPropertyDescriptor(HTMLTemplateElement.prototype,"content");
if(descriptor.set!==undefined||!descriptor.enumerable||!descriptor.configurable||Object.hasOwn(template,"content"))throw new Error("content descriptor");
const prefixed=document.createElementNS("http://www.w3.org/1999/xhtml","t:template");
if(!(prefixed instanceof HTMLTemplateElement)||prefixed.content.nodeType!==11)throw new Error("prefixed template");
for(const receiver of [null,{},host,document.createElementNS("urn:test","template")]){let rejected=false;try{descriptor.get.call(receiver);}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("template content brand");}
let readonly=false;try{(function(){"use strict";template.content=document.createDocumentFragment();})();}catch(error){readonly=error instanceof TypeError;}if(!readonly||template.content!==content)throw new Error("content readonly");
meta.content="changed";if(meta.content!=="changed"||meta.getAttribute("content")!=="changed")throw new Error("meta reflection");
content.firstChild.innerHTML="<i>updated</i>";
if(template.innerHTML!=="<span class=\"child\"><i>updated</i></span>"||content.querySelector("span > i").textContent!=="updated")throw new Error("inert content parsing and selectors");
host.appendChild(content.cloneNode(true));
if(host.firstChild.textContent!=="updated"||content.firstChild.textContent!=="updated")throw new Error("created content insertion");
globalThis.templateCreatedPassed=true;
'], runtime, mut messages)
	assert runtime.evaluate_host('templateCreatedPassed')! == 'true'
	assert messages == []string{}
}
