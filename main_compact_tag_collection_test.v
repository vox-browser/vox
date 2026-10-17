module main

import browserjs
import html

fn test_compact_tag_collections_are_live_for_document_and_detached_elements() {
	mut document :=
		html.parse_document('<!doctype html><div id="host"><i id="first" name="first-name">first</i></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
const descendants=host.getElementsByTagName("I"),all=document.getElementsByTagName("i");
const detached=document.createElement("div"),child=document.createElement("i");
detached.appendChild(child);
if(all.length!==1||descendants.length!==1||detached.getElementsByTagName("i")[0]!==child)throw new Error("tag collection scope");
if(descendants.namedItem("first-name")!==first||descendants.item(0)!==first)throw new Error("collection names");
host.appendChild(child);
if(all.length!==2||descendants.length!==2||detached.getElementsByTagName("*").length!==0)throw new Error("live collection append");
host.innerHTML="<span>replacement</span>";
if(all.length!==0||descendants.length!==0)throw new Error("live collection replacement");
globalThis.collectionsPassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('collectionsPassed')! == 'true'
	assert messages == []string{}
}

fn test_compact_tag_collections_preserve_svg_case_and_reject_invalid_receivers() {
	mut document :=
		html.parse_document('<!doctype html><div id="host"><svg><linearGradient id="gradient"></linearGradient></svg></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [
		r'
if(host.getElementsByTagName("linearGradient")[0]!==gradient||host.getElementsByTagName("lineargradient").length!==0)throw new Error("SVG tag case");
let receiver=false,symbol=false;
try{Element.prototype.getElementsByTagName.call({},"*");}catch(error){receiver=error instanceof TypeError;}
try{host.getElementsByTagName(Symbol());}catch(error){symbol=error instanceof TypeError;}
if(!receiver||!symbol)throw new Error("tag collection validation");
globalThis.namesPassed=true;
',
	], runtime, mut messages)
	assert runtime.evaluate_host('namesPassed')! == 'true'
	assert messages == []string{}
}
