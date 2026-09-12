module html

import dom

fn autofocus_test_document() (&dom.Document, &dom.Navigable) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.update_the_visibility_state(.visible)
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	return document, navigable
}

fn autofocus_test_insert_input(document &dom.Document) &dom.Element {
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic(err)
	}
	input.set_attribute_value('autofocus', '')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(input.as_node()) or { panic(err) }
	return input
}

fn test_rendering_update_flushes_autofocus_candidates() {
	document, _ := autofocus_test_document()
	input := autofocus_test_insert_input(document)
	assert document.autofocus_candidates() == [input]

	mut event_loop := EventLoop.create(.window)
	event_loop.register_document(document)
	event_loop.update_the_rendering()

	assert document.autofocus_processed_flag()
	assert document.autofocus_candidates().len == 0
	assert document.focused_area()? == input.as_node()
	event_loop.unregister_document(document)
}

fn test_autofocus_waits_for_script_blocking_stylesheets() {
	document, _ := autofocus_test_document()
	input := autofocus_test_insert_input(document)
	blocking_style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style')!
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.script_blocking_style_sheet_set << blocking_style

	assert mutable_document.take_autofocus_candidate_to_focus() == none
	assert document.autofocus_candidates() == [input]
	mutable_document.script_blocking_style_sheet_set.clear()
	assert mutable_document.take_autofocus_candidate_to_focus()? == input
}

fn test_sandboxed_automatic_features_prevent_autofocus_candidates() {
	document, _ := autofocus_test_document()
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	_ = autofocus_test_insert_input(document)

	assert document.autofocus_candidates().len == 0
	assert !document.autofocus_processed_flag()
}
