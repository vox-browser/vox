module main

import browserjs
import html

fn test_compact_element_content_follows_native_descendant_changes() {
	mut document := html.parse_document('<!doctype html><div id="cell"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const cell=document.getElementById("cell");
cell.innerHTML="<div></div><div></div>";
const first=cell.firstChild;
if(first.hasChildNodes())fail("empty child");
first.innerHTML="foo<b>bar</b>";
if(!first.hasChildNodes())fail("hasChildNodes after markup");
if(cell.innerHTML!=="<div>foo<b>bar</b></div><div></div>")fail("parent markup after child markup "+cell.innerHTML);
first.firstChild.data="xy";
if(cell.textContent!=="xybar"||cell.innerHTML!=="<div>xy<b>bar</b></div><div></div>")fail("character data "+cell.innerHTML);
first.lastChild.setAttribute("class","k");
if(cell.innerHTML!=="<div>xy<b class=\"k\">bar</b></div><div></div>")fail("attribute "+cell.innerHTML);
const created=document.createElement("p");
if(created.hasChildNodes())fail("created element");
created.appendChild(document.createTextNode("t"));
if(!created.hasChildNodes())fail("created element child");
console.log("content passed");
'], runtime, mut messages)
	assert messages == ['content passed']
}
