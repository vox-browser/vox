module html

import dom
import platform

fn test_parser_scope_boundaries_preserve_modes_without_per_query_vectors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut stack := StackOfOpenElements{}
	for tag in ['html', 'body', 'p', 'button', 'ol', 'div'] {
		stack.push(document.create_element_ns(ns_html, tag) or { panic(err) })
	}
	assert stack.has_in_scope('p')
	assert !stack.has_in_button_scope('p')
	assert stack.has_in_button_scope('ol')
	assert !stack.has_in_list_item_scope('button')
	assert stack.has_in_table_scope('p')
	before := platform.thread_arena_usage().used
	mut found := true
	for _ in 0 .. 1024 {
		found = found && stack.has_in_button_scope('ol')
			&& !stack.has_in_button_scope('p') && !stack.has_in_list_item_scope('button')
			&& stack.has_in_table_scope('p')
	}
	after := platform.thread_arena_usage().used
	assert found
	$if prealloc { assert after == before }
}
