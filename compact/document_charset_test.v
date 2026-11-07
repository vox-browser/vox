module main

import browserjs
import html

// characterSet has the legacy aliases charset and inputEncoding on every
// document, and a created document element keeps its prefix.
fn test_compact_documents_alias_character_set_and_keep_element_prefixes() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><meta charset=utf-8><body></body>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const xml=document.implementation.createDocument("urn:test","foo:bar",null);
const created=document.implementation.createHTMLDocument("");
console.log([document.charset,document.inputEncoding,xml.charset,xml.inputEncoding,created.charset,
 xml.documentElement.prefix,xml.documentElement.localName,xml.documentElement.tagName].join(" "));
'], runtime, mut messages)
	assert messages == ['UTF-8 UTF-8 UTF-8 UTF-8 UTF-8 foo bar foo:bar'], messages.str()
}
