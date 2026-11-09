module main

import browserjs
import dom
import platform

fn test_xml_navigation_preserves_svg_namespaces_cdata_and_script_order() {
	markup := '<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml"><title>日本語 ✓</title><g id="target"/><h:script src="support.js"/><script><![CDATA[xmlOrder.push("svg-inline");globalThis.xmlCheck=document.documentElement.namespaceURI+":"+document.getElementById("target").localName;]]></script></svg>'
	assert browser_navigation_response_markup(markup, 'image/svg+xml') == markup
	address := dom.URL{value: 'https://xml-navigation.test/page.svg'}
	prepared := prepare_loaded_browser_navigation_document(LoadedPage{url:address.serialize(), markup:markup,
		content_type:'Image/SVG+XML'}, address, none, none, none, true)
	mut document := prepared.document
	defer { document.finalize() }
	assert document.is_xml_document()
	parse_prepared_browser_navigation_document(prepared)
	assert !document.is_html_document()
	assert document.get_content_type() == 'image/svg+xml'
	root := document.document_element() or { panic('root') }
	assert root.local_name() == 'svg'
	assert root.namespace_uri()? == 'http://www.w3.org/2000/svg'
	assert document.get_element_by_id('target')?.local_name() == 'g'
	mut messages := []string{}
	sources := script_sources(document, address.serialize(), {
		'https://xml-navigation.test/support.js': PreloadedResource{body:'globalThis.xmlOrder=["html-external"];'}
	}, mut messages)
	assert sources.len == 2
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	run_document_script_sources(document, address.serialize(), sources, runtime, mut messages)
	assert messages == [], messages.join('\n')
	assert runtime.evaluate_host('JSON.stringify(xmlOrder)')! == '["html-external","svg-inline"]'
	assert runtime.evaluate_host('xmlCheck')! == 'http://www.w3.org/2000/svg:g'
}

fn test_xml_navigation_uses_transport_then_declaration_encoding_without_html_meta_sniffing() {
	address := dom.URL{value:'https://xml-navigation.test/document.xml'}
	for content_type, markup in {
		'application/xml': '<?xml version="1.0" encoding="windows-1251"?><root id="target">' + [u8(0xc4), 0xe0].bytestr() + '</root>'
		'application/xml;charset=windows-1251': '<?xml version="1.0" encoding="utf-8"?><root id="target">' + [u8(0xc4), 0xe0].bytestr() + '</root>'
	} {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{url:address.serialize(),markup:markup,content_type:content_type}, address,none,none,none,false)
		content := document.get_element_by_id('target')?.text_content()?
		assert content == 'Да', '${content_type} encoding=${document.character_set()} text=${content}'
		assert document.character_set() == 'windows-1251'
		document.finalize()
	}
	markup := '<root><meta charset="windows-1251"/><item id="target">日本語 ✓</item></root>'
	mut document := parse_loaded_browser_navigation_document(LoadedPage{url:address.serialize(),markup:markup,content_type:'application/xml'},address,none,none,none,false)
	defer { document.finalize() }
	assert document.get_element_by_id('target')?.text_content()? == '日本語 ✓'
	assert document.character_set() == 'UTF-8'
}

fn test_xml_navigation_replaces_malformed_markup_with_an_xml_error_document() {
	address := dom.URL{value:'https://xml-navigation.test/broken.svg'}
	mut document := parse_loaded_browser_navigation_document(LoadedPage{url:address.serialize(),markup:'<svg xmlns="http://www.w3.org/2000/svg"><g></svg>',content_type:'image/svg+xml'},address,none,none,none,true)
	defer { document.finalize() }
	assert document.document_element()?.local_name() == 'parsererror'
	assert !document.is_html_document()
}

fn test_xml_navigation_and_preload_keep_tokens_after_decoded_input_storage_retires() {
	loaded := LoadedPage{url:'https://xml-navigation.test/tokens.svg',content_type:'image/svg+xml',
		markup:'<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml"><text id="target" data-note="日本語">日本語 ✓</text><h:script src="support.js"/><script><![CDATA[globalThis.xmlTokenProbe="<cdata>";]]></script></svg>'}
	for discovery in [false, true] {
		mut document := if discovery { parse_page_preload_document(loaded, true) } else {
			parse_loaded_browser_navigation_document(loaded, dom.URL{value:loaded.url},none,none,none,true)
		}
		for _ in 0 .. 8 {
			reuse := platform.begin_thread_scratch('reuse XML decoded input')
			_ = []u8{len:262144,init:0xa5}
			reuse.finish()
		}
		target := document.get_element_by_id('target') or { panic('target') }
		assert target.text_content()? == '日本語 ✓'
		assert target.get_attribute_value('data-note') == '日本語'
		assert target.namespace_uri()? == 'http://www.w3.org/2000/svg'
		assert document_preload_resource_urls(document, loaded.url) == ['https://xml-navigation.test/support.js']
		mut messages := []string{}
		sources := script_sources(document, loaded.url, {'https://xml-navigation.test/support.js': PreloadedResource{body:'// support'}},mut messages)
		assert sources.len == 2
		assert sources[1].code == 'globalThis.xmlTokenProbe="<cdata>";'
		assert messages == []
		$if prealloc {
			script := sources[1].element or { panic('script') }
			data := script.as_node().children_as_vector()[0].as_character_data() or { panic('CDATA') }
			assert document.native_storage().arena.contains(data.data().str)
		}
		if discovery { assert document.get_window() == none }
		document.finalize()
		document.release_native_storage()
	}
}
