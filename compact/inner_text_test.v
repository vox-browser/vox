module main

import browserjs
import html

fn test_inner_and_outer_text_read_and_replace_element_text() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="box">a<span id="s">b</span>c</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const created=document.createElement("p");created.innerHTML="x<b>y</b>";console.log(box.innerText,created.innerText,typeof Object.getOwnPropertyDescriptor(HTMLElement.prototype,"innerText").set);box.innerText="one\\ntwo";console.log(box.innerHTML,box.childNodes.length);const s2=document.createElement("span");s2.textContent="S";box.insertBefore(s2,box.lastChild);s2.outerText="mid";console.log(box.innerHTML,box.childNodes.length);box.innerText=null;console.log(JSON.stringify(box.innerHTML));try{document.createElement("i").outerText="x"}catch(e){console.log(e.name)}',
	], runtime, mut messages)
	assert messages == ['abc xy function', 'one<br>two 3', 'one<br>midtwo 3', '""',
		'NoModificationAllowedError']
}
