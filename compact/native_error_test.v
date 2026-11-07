module main

import browserjs
import dom
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

fn test_an_xml_document_exposes_its_own_root() {
	$if !darwin { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	html.install_document_fragment_parsing_hook(document)
	html.parse_xml_document_source(document, '<foo>Dummy XML document</foo>\n') or { panic(err) }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'console.log(document.documentElement.localName,document.documentElement.textContent,String(document.body));',
	], runtime, mut messages)
	assert messages == ['foo Dummy XML document null']
}
