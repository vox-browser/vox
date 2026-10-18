module layout

import dom
import html

fn retained_inline_paint_check(document &dom.Document, id string) {
	element := document.get_element_by_id(id) or { panic('missing paint owner') }
	node := unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
	result := document_layout_result(document) or { panic('missing layout result') }
	styled := node.as_node_with_style() or { panic('missing styled node') }
	used := result.state.try_get(styled) or { panic('missing geometry') }
	position := paint_cumulative_offset(node, result.state, used)
	actual := text_lines_from_typed_layout(node, used, result.state, position)
	expected := uncached_text_lines_from_typed_layout(node, used, result.state, position)
	assert actual.str() == expected.str()
}

fn test_retained_inline_paint_rebases_text_and_inline_decorations_exactly() {
	mut document :=
		html.parse_document('<!doctype html><style>p{width:180px}strong{border:2px solid blue;text-decoration:underline;outline:1px solid red;background:yellow}</style><div id="changed"></div><p id="text">Text with <strong>decorated inline text</strong> and trailing content.</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	_ = document.record_display_list()?
	retained_inline_paint_check(document, 'text')
	mut changed := document.get_element_by_id('changed')?
	for content in ['<p>new preceding content</p>', '', '<p>one</p><p>two</p>'] {
		changed.set_inner_html(content)!
		document.update_layout(.debugging)
		retained_inline_paint_check(document, 'text')
		current := (document.record_display_list()?).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list()?).dump() == current
	}
}

fn test_retained_inline_paint_observes_live_color_selection_and_background_image_styles() {
	mut document :=
		html.parse_document('<!doctype html><style>.red{color:red}.red::selection{color:yellow;background:blue}.blue{color:blue}.blue::selection{color:red;background:green}</style><div id="changed"></div><p id="text" class="red">An <strong>inline child</strong> with selection colors.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	_ = document.record_display_list()?
	mut text := document.get_element_by_id('text')?
	for class_name in ['blue', 'red'] {
		text.set_attribute_value('class', class_name)
		document.update_layout(.debugging)
		retained_inline_paint_check(document, 'text')
	}
	text.set_attribute_value('style', 'background-image:linear-gradient(red,blue)')
	document.update_layout(.debugging)
	retained_inline_paint_check(document, 'text')
}

fn test_retained_inline_paint_preserves_old_transport_arrays_after_a_rebase() {
	mut document :=
		html.parse_document('<!doctype html><div id="changed"></div><p id="text">Retained transport keeps old coordinates and glyph ownership.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	old := document.record_display_list()?
	old_dump := old.dump()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>move the paragraph</p>')!
	document.update_layout(.debugging)
	_ = document.record_display_list()?
	gc_collect()
	assert old.dump() == old_dump
	retained_inline_paint_check(document, 'text')
}
