module html

import dom
import platform

fn tokenizer_storage_assert_owned_tree(node &dom.Node, storage &platform.Arena) {
	if element := node.as_element() {
		assert !storage.contains(element.local_name().str)
		for name in element.get_attribute_names() {
			assert !storage.contains(name.str)
			assert !storage.contains(element.get_attribute_value(name).str)
		}
		if element.local_name() == 'template' {
			template := unsafe { &dom.HTMLTemplateElement(element) }
			tokenizer_storage_assert_owned_tree(template.content().as_node(), storage)
		}
	}
	if node.is_comment() || node.is_text() {
		text := unsafe { &dom.CharacterData(node) }
		assert !storage.contains(text.data().str)
	}
	for child := node.first_child(); child != none; {
		current := child or { break }
		tokenizer_storage_assert_owned_tree(current, storage)
		child = current.next_sibling()
	}
}

fn test_native_disabled_tokenizer_retires_payloads_with_owned_dom_and_source() {
	mut document := dom.Document.create(dom.URL{ value: 'https://tokenizer-storage.test/' })
	document.set_scripting_enabled_by_embedder(false)
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	mut scope := document.enter_native_storage()
	defer { scope.finish() }
	markup := '<!--initial--><!DOCTYPE html PUBLIC "public identifier" "system identifier"><!--before-html-->' +
		'<html><head><style id="style">p{color:red}</style></head><body><html data-root="late root"><body data-body="late body">' +
		'<custom-element id="target" is="custom-kind" data-value="&amp;日本語😀">owned text</custom-element>' +
		'<svg id="graphic" viewBox="0 0 10 20"><use id="use" xlink:href="#shape"/></svg>' +
		'<template id="template"><b class="nested">template text</b></template>' +
		'<p><b data-formatting="original">one<i>two</b>three</i></p><!--in-body--></body><!--after-body--></html><!--after-html-->'
	mut parser := HTMLParser.create(document, markup)
	storage := parser.tokenizer_storage
	$if prealloc {
		assert storage != unsafe { nil }
		assert storage.usage().used >= markup.runes().len * int(sizeof(rune))
		assert !storage.contains(parser.tokenizer.source().str)
	}
	// Leave the final comment unconsumed so ownership can be checked while
	// borrowed tokenizer memory is still mapped.
	parser.tokenizer.insertion_point = markup.runes().len - '<!--after-html-->'.len
	parser.run_until_insertion_point()
	$if prealloc {
		assert storage.usage().capacity > 0
		tokenizer_storage_assert_owned_tree(document.as_node(), storage)
		doctype := document.doctype()?
		assert !storage.contains(doctype.name().str)
		assert !storage.contains(doctype.public_id().str)
		assert !storage.contains(doctype.system_id().str)
	}
	parser.tokenizer.undefine_insertion_point()
	parser.run()
	$if prealloc {
		assert parser.tokenizer_storage == unsafe { nil }
		assert storage.usage().capacity == 0
	}
	assert parser.tokenizer.source() == markup
	assert parser.tokenizer.unparsed_input() == ''
	assert parser.tokenizer.next_token() == none
	assert parser.tokenizer.nth_last_position(0) == Position{0, markup.runes().len}
	assert document.readiness() == .complete
	assert document.doctype()?.name() == 'html'
	assert document.doctype()?.public_id() == 'public identifier'
	assert document.doctype()?.system_id() == 'system identifier'
	assert document.document_element()?.get_attribute_value('data-root') == 'late root'
	assert document.body()?.get_attribute_value('data-body') == 'late body'
	target := document.get_element_by_id('target')?
	assert target.local_name() == 'custom-element'
	assert target.get_attribute_value('is') == 'custom-kind'
	assert target.get_attribute_value('data-value') == '&日本語😀'
	assert target.as_node().text_content()? == 'owned text'
	assert document.get_element_by_id('style')?.as_node().text_content()? == 'p{color:red}'
	assert document.get_element_by_id('graphic')?.get_attribute_value('viewBox') == '0 0 10 20'
	assert document.get_element_by_id('use')?.get_attribute_ns('http://www.w3.org/1999/xlink', 'href')? == '#shape'
	template := unsafe { &dom.HTMLTemplateElement(document.get_element_by_id('template')?) }
	assert template.content().as_node().text_content()? == 'template text'
	last := document.as_node().last_child()?
	assert last.is_comment()
	assert unsafe { &dom.CharacterData(last) }.data() == 'after-html'
}

fn test_native_tokenizer_payloads_retire_with_document_before_eof() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_scripting_enabled_by_embedder(false)
		document.enable_native_storage()
		mut scope := document.enter_native_storage()
		parser := HTMLParser.create(document, '<p>not yet parsed</p>')
		storage := parser.tokenizer_storage
		assert storage.usage().used > 0
		scope.finish()
		document.finalize()
		document.release_native_storage()
		assert storage.usage().capacity == 0
	}
}

fn test_streaming_native_parser_keeps_its_separate_input_lifetime() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	mut scope := document.enter_native_storage()
	defer { scope.finish() }
	mut parser := HTMLParser.create_with_open_input_stream(document)
	assert parser.tokenizer_storage == unsafe { nil }
	parser.tokenizer.feed('<p id="stream">first ')
	parser.run()
	assert document.get_element_by_id('stream')?.as_node().text_content()? == 'first '
	parser.tokenizer.feed('second</p>')
	parser.tokenizer.insert_eof()
	parser.run()
	assert document.get_element_by_id('stream')?.as_node().text_content()? == 'first second'
}
