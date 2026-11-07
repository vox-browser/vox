module main

import browserjs
import html

fn test_native_dom_errors_reach_script_as_dom_exceptions() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><p id="p">x</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'for(const [ns,name] of [[null,"1x"],["http://www.w3.org/2000/xmlns/","a"],[null,"a:b"]]){try{document.createElementNS(ns,name);console.log("no error")}catch(e){console.log(e instanceof DOMException,e.name,e.code)}}',
	], runtime, mut messages)
	assert messages == ['true InvalidCharacterError 5', 'true NamespaceError 14', 'true NamespaceError 14']
}
