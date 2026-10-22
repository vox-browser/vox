module layout

import css
import dom
import html
import platform

fn test_tree_builder_counter_history_retires_without_retaining_its_hash_tables() {
	mut document := html.parse_document('<!doctype html><div id="scope" style="counter-reset:n 7"><p id="child" style="counter-increment:n 3"></p></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	parent_element := document.get_element_by_id('scope')?
	child_element := document.get_element_by_id('child')?
	parent := dom.AbstractElement.new(parent_element, none)
	child := dom.AbstractElement.new(child_element, none)
	parent_style := css.computed_properties_for_element(parent.element())?
	child_style := css.computed_properties_for_element(child.element())?
	mut builder := new_tree_builder_state()
	resolve_layout_counters(mut builder, parent, parent_style)
	resolve_layout_counters(mut builder, child, child_style)
	retained := css.counters_set_for_abstract_element(&child)?
	assert retained.counters().last().value? == 10
	before := platform.thread_arena_usage().used
	for index in 0 .. 4096 { builder.remember_counters(index + 10000, retained, index + 20000) }
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 4096
		assert builder.workspace.usage().used > 4096 * 16
	}
	assert builder.counter_sets[12345].counters().last().value? == 10
	assert builder.last_child_by_parent[22345] == 12345
	builder.finish()
	// The DOM snapshot must survive even when the workspace is poisoned.
	assert retained.counters().last().value? == 10
	assert css.counters_set_for_abstract_element(&child)?.dump() == retained.dump()
}

fn test_tree_builder_history_retirement_preserves_pseudo_content_and_rebuilds() {
	mut document := html.parse_document('<!doctype html><style>main{counter-reset:n 4}p{counter-increment:n}p::before{content:counter(n) ". "}span::before{display:block;content:"before"}span::after{display:block;content:"after"}</style><main><p>first</p><p><span>second</span></p></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	assert_tree_builder_generated_content(document)
	expected := (document.record_display_list() or { panic('missing recording') }).dump()
	for _ in 0 .. 3 {
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert_tree_builder_generated_content(document)
		actual := (document.record_display_list() or { panic('missing rebuilt recording') }).dump()
		assert actual == expected
	}
}

fn assert_tree_builder_generated_content(document &dom.Document) {
	result := document_layout_result(document) or { panic('missing layout tree') }
	text := tree_builder_generated_text(result.root)
	assert text.contains('5. ')
	assert text.contains('6. ')
	assert text.contains('before')
	assert text.contains('after')
}

fn tree_builder_generated_text(node &Node) string {
	mut text := ''
	if node.is_generated_text_node() {
		text_node := node.as_text_node() or { panic('missing generated text') }
		text = text_node.text_for_rendering()
	}
	for child in node.children() {
		text += tree_builder_generated_text(child)
	}
	return text
}
