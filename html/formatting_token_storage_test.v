module html

import dom
import platform

fn test_parser_formatting_snapshots_and_entry_growth_use_tokenizer_storage() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	element := document.create_element('b') or { panic(err) }
	mut storage := platform.new_arena('parser formatting snapshots')
	mut list := ListOfActiveFormattingElements{parser_storage:storage}
	mut token := HTMLToken.make_start_tag('b')
	token.add_attribute(Attribute{local_name:'data-value', value:'original'})
	mut allocations := document.enter_native_storage()
	before := document.native_storage().arena.usage().used
	for index in 0 .. 1024 { list.insert_at(index, element, &token) }
	assert document.native_storage().arena.usage().used - before < 16 * 1024
	assert storage.contains(list.entries.data)
	for entry in list.entries {
		stored := entry.token or { panic('missing token') }
		assert storage.contains(stored)
		assert storage.contains(stored.attributes.data)
		assert stored.attribute('data-value')? == 'original'
	}
	// The existing public snapshot method remains caller-owned even when used
	// on a parser list. Its independent token survives parser storage teardown.
	owned := list.create_own_token(&token)
	assert !storage.contains(owned)
	list.entries = []ActiveFormattingElement{}
	list.parser_storage = unsafe { nil }
	storage.release()
	assert owned.attribute('data-value')? == 'original'
	allocations.finish()
	document.release_native_storage()
}

fn test_native_formatting_reconstruction_matches_the_original_parser_after_retirement() {
	for markup in [
		'<p><b data-x="&amp;日本語">one<i>two</b>three</i>four',
		'<table><b class="foster">before<tr><td><i>cell</b>after</i></td></tr></table>',
		'<b><b><b><b><b>one</p>two</b>three',
		'<template><b data-x="one">template<i>nested</b>tail</i></template><p>outside',
	] {
		mut original := dom.Document.create(dom.url_about_blank())
		original.set_scripting_enabled_by_embedder(false)
		mut reference := HTMLParser.create(original, markup)
		reference.run()
		expected := original.document_element()?.outer_html() or { panic(err) }
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_scripting_enabled_by_embedder(false)
		document.enable_native_storage()
		mut allocations := document.enter_native_storage()
		mut parser := HTMLParser.create(document, markup)
		parser.run()
		assert parser.tokenizer_storage == unsafe { nil }
		$if prealloc { assert parser.list_of_active_formatting_elements.entries.len == 0 }
		assert parser.list_of_active_formatting_elements.parser_storage == unsafe { nil }
		actual := document.document_element()?.outer_html() or { panic(err) }
		assert actual == expected
		allocations.finish()
		document.finalize()
		document.release_native_storage()
		original.finalize()
	}
}
