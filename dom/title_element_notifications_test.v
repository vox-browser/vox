// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module dom

fn title_notification_document() !(&Document, &Page, &Element) {
	mut document := Document.create(url_about_blank())
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	page := &Page{}
	document.set_page(page)
	document.set_cached_navigable(&Navigable{active_document_: document, is_top_level_traversable_: true})
	head := document.head() or { return error('missing head') }
	return document, page, unsafe { &Element(head) }
}

// Ladybird df3a4efd8d8d58a3acd8e85269e78b54ab009628.
fn test_title_insertion_replacement_and_removal_notify_current_title() {
	mut document, page, head := title_notification_document()!
	defer { document.finalize() }
	mut head_node := head.as_node()
	mut original := document.create_element('title')!
	mut original_node := original.as_node()
	original_node.string_replace_all('TITLE_A')
	assert page.title_change_count() == 0
	head_node.append_child(original_node)!
	assert page.last_changed_title() == 'TITLE_A'
	mut replacement := document.create_element('title')!
	mut replacement_node := replacement.as_node()
	before := page.title_change_count()
	replacement_node.string_replace_all('TITLE_B')
	assert page.title_change_count() == before
	head_node.replace_child(replacement_node, original_node)!
	assert page.last_changed_title() == 'TITLE_B'
	before_detached_edit := page.title_change_count()
	original_node.string_replace_all('detached')
	assert page.title_change_count() == before_detached_edit
	head_node.remove_child(replacement_node)!
	assert page.last_changed_title() == ''
	head_node.append_child(original_node)!
	assert page.last_changed_title() == 'detached'
}

fn test_removing_first_title_reports_the_next_title_and_connected_text_changes() {
	mut document, page, head := title_notification_document()!
	defer { document.finalize() }
	mut head_node := head.as_node()
	mut first := document.create_element('title')!
	mut first_node := first.as_node()
	first_node.string_replace_all('first')
	mut second := document.create_element('title')!
	mut second_node := second.as_node()
	second_node.string_replace_all('second')
	head_node.append_child(first_node)!
	head_node.append_child(second_node)!
	assert page.last_changed_title() == 'first'
	head_node.remove_child(first_node)!
	assert page.last_changed_title() == 'second'
	second_node.string_replace_all('changed')
	assert page.last_changed_title() == 'changed'
}
