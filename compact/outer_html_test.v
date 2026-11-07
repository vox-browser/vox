module main

import browserjs
import html

fn test_element_outer_html_serializes_and_replaces_the_element() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="box"><p id="old" class="c">a<b>b</b></p></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const old=document.getElementById("old");console.log(old.outerHTML,document.documentElement.outerHTML.slice(0,12));old.outerHTML="<i id=n>x</i>tail";console.log(box.innerHTML,old.isConnected,old.outerHTML,document.getElementById("n").textContent);const loose=document.createElement("span");loose.textContent="free";console.log(loose.outerHTML);loose.outerHTML="<b>ignored</b>";console.log(loose.outerHTML);try{document.documentElement.outerHTML="<p>"}catch(e){console.log(e.name)}console.log(typeof Object.getOwnPropertyDescriptor(Element.prototype,"outerHTML").set)',
	], runtime, mut messages)
	assert messages == ['<p id="old" class="c">a<b>b</b></p> <html><head>',
		'<i id="n">x</i>tail false <p id="old" class="c">a<b>b</b></p> x',
		'<span>free</span>', '<span>free</span>', 'NoModificationAllowedError', 'function']
}
