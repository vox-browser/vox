module layout

import css
import dom
import platform

fn test_unchanged_rendered_text_needs_no_utf16_or_whitespace_buffers() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parent := BlockContainer.new(document, none, css.ComputedProperties.new())
	mut parent_node := unsafe { &Node(parent) }
	mut warm := TextNode.new_generated(document, 'warm')
	parent_node.append_child(unsafe { &Node(warm) })
	assert warm.text_for_rendering() == 'warm'
	source := 'plain 中😀'.repeat(8192)
	mut text := TextNode.new_generated(document, source)
	parent_node.append_child(unsafe { &Node(text) })
	before := platform.thread_arena_usage().used
	actual := text.text_for_rendering()
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert actual == source
	assert text.rendered_utf16_length() == 9 * 8192
	assert text.rendered_source_length_ == 9 * 8192
}

fn test_whitespace_replacement_retains_one_exact_rendered_buffer() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parent := BlockContainer.new(document, none, css.ComputedProperties.new())
	mut parent_node := unsafe { &Node(parent) }
	mut warm := TextNode.new_generated(document, 'warm')
	parent_node.append_child(unsafe { &Node(warm) })
	assert warm.text_for_rendering() == 'warm'
	source := 'a\t中\n😀'.repeat(8192)
	mut text := TextNode.new_generated(document, source)
	parent_node.append_child(unsafe { &Node(text) })
	before := platform.thread_arena_usage().used
	actual := text.text_for_rendering()
	$if prealloc { assert platform.thread_arena_usage().used - before < source.len + 4096 }
	assert actual == 'a 中 😀'.repeat(8192)
	assert source.starts_with('a\t中\n😀')
	assert unsafe { actual.str[actual.len] } == 0
}
