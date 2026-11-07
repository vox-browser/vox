module main

import browserjs
import dom
import html

fn test_anchor_urls_of_a_gb18030_document_encode_their_query_with_it() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><a id="parsed" href="https://example.com/?%E2%82%AC=€">p</a>')
	mut owner := unsafe { &dom.Document(document) }
	owner.set_encoding('gb18030')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const a=document.createElement("a");a.href="https://example.com/?\\u20AC";console.log(document.characterSet,a.search,a.href,parsed.search);',
	], runtime, mut messages)
	assert messages == ['gb18030 ?%A2%E3 https://example.com/?%A2%E3 ?%E2%82%AC=%A2%E3']
}
