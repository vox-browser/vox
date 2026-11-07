module layout

import dom
import html

fn line_reuse_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element ${id}') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout ${id}') }.real_layout_handle()) }
}

fn line_reuse_lines(document &dom.Document, id string) []LineBox {
	result := document_layout_result(document) or { panic('missing layout') }
	node := line_reuse_node(document, id)
	styled := node.as_node_with_style() or { panic('unstyled') }
	values := result.state.used_values_store.get(styled.layout_index()) or { panic('missing values') }
	return values.line_boxes
}

fn line_reuse_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

// Generated content keeps this paragraph out of the retained inline cache, so
// every pass lays it out again in the closed workspace.
fn line_reuse_document() &dom.Document {
	return html.parse_document('<!doctype html><style>#para::before{content:"Note: "}</style><div id="changed"></div><p id="para" style="width:180px">Unchanged words that wrap across several lines of text.</p>')
}

fn test_unchanged_closed_inline_context_shares_the_previous_lines() {
	mut document := line_reuse_document()
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 400, 300)
	first := line_reuse_lines(document, 'para')
	assert first.len > 1
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'height:20px')
	document.update_layout(.debugging)
	second := line_reuse_lines(document, 'para')
	assert published_line_boxes_equal(first, second)
	// The closed workspace exists only for preallocated native documents.
	$if prealloc {
		assert voidptr(second.data) == voidptr(first.data)
	}
	line_reuse_assert_full_layout(mut document)
}

fn test_changed_closed_inline_context_publishes_new_lines() {
	mut document := line_reuse_document()
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 400, 300)
	first := line_reuse_lines(document, 'para')
	mut para := document.get_element_by_id('para')?
	para.set_attribute_value('style', 'width:120px')
	document.update_layout(.debugging)
	second := line_reuse_lines(document, 'para')
	assert voidptr(second.data) != voidptr(first.data)
	assert !published_line_boxes_equal(first, second)
	assert second.len > first.len
	line_reuse_assert_full_layout(mut document)
}

fn test_line_equality_compares_glyph_content() {
	mut document := line_reuse_document()
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	lines := line_reuse_lines(document, 'para')
	mut copy := own_inline_layout_lines(lines)
	assert published_line_boxes_equal(lines, copy)
	for mut line in copy {
		for mut fragment in line.fragments_ {
			if mut run := fragment.glyph_run_ {
				run.glyphs_ = run.glyphs_.clone()
				run.glyphs_[0].glyph_index += 1
				assert !published_line_boxes_equal(lines, copy)
				return
			}
		}
	}
	assert false
}
