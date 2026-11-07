module main

import browserjs
import html

fn test_compact_created_child_clones_retain_native_subtrees_and_parent_identity() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
const probe=document.createElement("div"),input=document.createElement("input");
input.setAttribute("type","checkbox");input.setAttribute("checked","");probe.appendChild(input);
const copy=probe.cloneNode(true).cloneNode(true),last=copy.lastChild;
if(!last||last.nodeType!==1||last.tagName!=="INPUT"||last.getAttribute("type")!=="checkbox")throw new Error("jQuery clone support probe lost child");
if(last.parentNode!==copy||copy.lastChild!==last||last===input)throw new Error("clone child identity");
host.appendChild(copy);
if(host.lastChild!==copy||copy.lastChild!==last)throw new Error("inserted clone identity");
globalThis.clonePassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('clonePassed')! == 'true'
	assert messages == []string{}
}

fn test_compact_last_child_preserves_character_data_and_native_mutations() {
	mut document :=
		html.parse_document('<!doctype html><div id="host"><b>child</b>tail<!--end--></div><div id="empty"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
const comment=host.lastChild;
if(comment.nodeType!==8||comment.nodeName!=="#comment"||comment.data!=="end"||comment.parentNode!==host||host.lastChild!==comment)throw new Error("comment identity");
comment.nodeValue="Привет";
if(comment.textContent!=="Привет"||!host.innerHTML.includes("<!--Привет-->"))throw new Error("native character data write");
const clone=comment.cloneNode();
if(clone===comment||clone.nodeValue!=="Привет"||clone.parentNode!==null)throw new Error("character data clone");
if(empty.lastChild!==null)throw new Error("empty lastChild");
globalThis.characterDataPassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('characterDataPassed')! == 'true'
	assert messages == []string{}
}
