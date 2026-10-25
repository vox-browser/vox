module layout

import html
import painting

fn test_exact_fragment_hits_preserve_overflow_and_nearest_cursor_edges() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{width:10px;white-space:nowrap;line-height:20px}</style><p id="target" contenteditable>one 😀 two three</p>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 320, 100)
	target := document.get_element_by_id('target') or { panic('missing target') }
	text := target.as_node().first_child() or { panic('missing text') }
	box := root.find_box(i64(target.as_node().unique_id())) or { panic('missing box') }
	fragment := box.lines[0].fragments.last().paintable_fragment
	rect := fragment.absolute_rect()
	point := painting.Point{rect.right() - 1, rect.y + rect.height / 2}
	border := box.border_box()
	assert point.x > border.x + border.width
	viewport := document.paintable_box() or { panic('missing viewport') }
	hit := viewport.hit_test(point.x, point.y, .exact) or { panic('missing overflow hit') }
	assert voidptr(hit.node) == voidptr(text)
	assert hit.index_in_node == fragment.index_in_node_for_point(point)

	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(text, 0) or { panic(err) }
	cursor := viewport.hit_test(rect.right() + 12, point.y, .text_cursor) or {
		panic('missing nearest cursor hit')
	}
	assert voidptr(cursor.node) == voidptr(text)
	assert cursor.index_in_node == fragment.source_end_offset()
	assert (cursor.horizontal_distance or { panic('missing cursor distance') }) == 12
}

fn test_exact_fragment_hits_still_filter_pointer_events_and_inert_text() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{position:absolute;left:0;top:0;line-height:20px}#under{z-index:0}#disabled{z-index:1;pointer-events:none}#inert{z-index:2}</style><p id="under">underlying text</p><p id="disabled">disabled text</p><p id="inert" inert>inert text</p>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 320, 100)
	under := document.get_element_by_id('under') or { panic('missing underlay') }
	text := under.as_node().first_child() or { panic('missing text') }
	box := root.find_box(i64(under.as_node().unique_id())) or { panic('missing box') }
	rect := box.lines[0].fragments[0].paintable_fragment.absolute_rect()
	viewport := document.paintable_box() or { panic('missing viewport') }
	hit := viewport.hit_test(rect.x + 1, rect.y + rect.height / 2, .exact) or {
		panic('missing filtered hit')
	}
	assert voidptr(hit.node) == voidptr(text)
	assert voidptr(hit.element) == voidptr(under)
}
