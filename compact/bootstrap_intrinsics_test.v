module main

import browserjs
import html

fn test_compact_document_bootstrap_initializes_intrinsics_without_author_scripts() {
	mut document := html.parse_document('<!doctype html><body><a id="anchor" href="child">link</a></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://bootstrap.test/base/', [], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('document.getElementById("anchor").href')! == 'https://bootstrap.test/base/child'
	assert runtime.evaluate_host('document.getElementById("anchor").href')! == 'https://bootstrap.test/base/child'
}

fn test_compact_document_bootstrap_finishes_before_author_dom_queries() {
	mut document := html.parse_document('<!doctype html><body><a id="anchor" href="../first">link</a></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://bootstrap.test/base/', [r'
const anchor=document.getElementById("anchor");
if(anchor.href!=="https://bootstrap.test/first")throw new Error("initial href");
anchor.setAttribute("href","next");
if(anchor.href!=="https://bootstrap.test/base/next")throw new Error("changed href");
document.body.setAttribute("data-bootstrap","ready");
globalThis.compactBootstrapReady=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('compactBootstrapReady')! == 'true'
	assert document.body()?.as_element()?.get_attribute_value('data-bootstrap') == 'ready'
}
