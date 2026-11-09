module main

import browserjs
import html

fn check_compact_content_invalidation(source string) ! {
	mut document := html.parse_document('<!doctype html><div id="host"><p id="word">abc</p><p id="tail">tail</p></div><div id="other">unchanged</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://content-invalidation.test/', [source], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('contentInvalidationPassed')! == 'true'
}

fn test_content_reads_follow_all_native_range_mutations_and_selection_deletion() {
	check_compact_content_invalidation(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
check(host.textContent,"abctail");check(word.innerHTML,"abc");check(other.innerHTML,"unchanged");
const range=document.createRange(),bold=document.createElement("b");bold.textContent="X";
range.setStart(word.firstChild,1);range.collapse(true);range.insertNode(bold);
check(word.innerHTML,"a<b>X</b>bc");check(host.textContent,"aXbctail");
range.selectNode(bold);const extracted=range.extractContents();
check(extracted.firstChild,bold);check(word.textContent,"abc");check(word.innerHTML,"abc");
range.selectNodeContents(word);const wrapper=document.createElement("em");range.surroundContents(wrapper);
check(word.innerHTML,"<em>abc</em>");check(host.innerHTML,"<p id=\"word\"><em>abc</em></p><p id=\"tail\">tail</p>");
range.selectNodeContents(wrapper);range.deleteContents();check(word.innerHTML,"<em></em>");check(host.textContent,"tail");
wrapper.textContent="1234";check(host.textContent,"1234tail");range.setStart(wrapper.firstChild,1);range.setEnd(wrapper.firstChild,3);
const selection=getSelection();selection.removeAllRanges();selection.addRange(range);selection.deleteFromDocument();
check(wrapper.textContent,"14");check(host.textContent,"14tail");check(other.innerHTML,"unchanged");
globalThis.contentInvalidationPassed=true;
')!
}

fn test_detached_created_content_and_pending_writes_survive_native_invalidation() {
	check_compact_content_invalidation(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const detached=document.createElement("section");detached.innerHTML="<span>ab</span>";const child=detached.firstChild;
check(detached.textContent,"ab");check(detached.innerHTML,"<span>ab</span>");
const range=document.createRange();range.setStart(child.firstChild,1);range.collapse(true);range.insertNode(document.createTextNode("X"));
detached.setAttribute("data-pending","kept");check(detached.innerHTML,"<span>aXb</span>");check(detached.textContent,"aXb");
child.textContent="pending replacement";range.selectNodeContents(word);range.deleteContents();
check(child.textContent,"pending replacement");host.appendChild(detached);
check(detached.getAttribute("data-pending"),"kept");check(detached.innerHTML,"<span>pending replacement</span>");
range.selectNodeContents(child);range.deleteContents();
const fresh=document.createElement("i");check(fresh.innerHTML,"");fresh.textContent="fresh";check(fresh.textContent,"fresh");
check(detached.textContent,"");check(detached.innerHTML,"<span></span>");check(fresh.textContent,"fresh");
globalThis.contentInvalidationPassed=true;
')!
}

fn test_range_content_invalidation_does_not_enumerate_unrelated_wrappers() {
	check_compact_content_invalidation(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected))};
other.innerHTML="<span>unrelated</span>".repeat(1024);const unrelated=other.querySelectorAll("span");check(unrelated.length,1024);
check(host.innerHTML,"<p id=\"word\">abc</p><p id=\"tail\">tail</p>");
const range=document.createRange();range.setStart(word.firstChild,1);range.collapse(true);const added=document.createTextNode("X");
let wideEnumerations=0;const keys=Object.keys;
try{Object.keys=function(object){const result=keys(object);if(result.length>=1024)wideEnumerations++;return result};range.insertNode(added)}finally{Object.keys=keys}
check(wideEnumerations,0);check(word.textContent,"aXbc");check(unrelated[1000].textContent,"unrelated");
globalThis.contentInvalidationPassed=true;
')!
}

fn test_canvas_replay_keeps_native_range_edits_to_its_fallback_content() {
	check_compact_content_invalidation(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected))};
const canvas=document.createElement("canvas");canvas.width=2;canvas.height=2;canvas.textContent="fallback";host.appendChild(canvas);
const context=canvas.getContext("2d"),range=document.createRange();check(canvas.innerHTML,"fallback");
range.setStart(canvas.firstChild,0);range.collapse(true);range.insertNode(document.createTextNode("X"));
context.fillStyle="red";context.fillRect(0,0,1,1);
check(canvas.textContent,"Xfallback");check(canvas.innerHTML,"Xfallback");check(canvas.childNodes.length,3);
globalThis.contentInvalidationPassed=true;
')!
}
