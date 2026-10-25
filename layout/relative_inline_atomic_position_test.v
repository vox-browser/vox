module layout

import css
import html

fn test_atomic_inline_paint_inherits_relative_inline_ancestors_once() {
	mut document := html.parse_document($embed_file('../Tests/Browser/Brave/input/relative-inline-atomic-position.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
	// The same rectangles are exposed by Brave's getBoundingClientRect().
	for id, expected in {
		'plain':       [3.0, 2.0]
		'nested':      [8.0, 46.0]
		'own':         [10.0, 88.0]
		'svg-box':     [3.0, 122.0]
		'content-box': [3.0, 162.0]
	} {
		element := document.get_element_by_id(id) or { panic('missing ' + id) }
		node := unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
		styled := node.as_node_with_style() or { panic('missing style') }
		used := result.state.try_get(styled) or { panic('missing geometry') }
		position := paint_cumulative_offset(node, result.state, used)
		assert position == css.CSSPixelPoint.from_values(expected[0], expected[1]), id
		// Projection caching must use the same ancestor offsets.
		scope := begin_paint_coordinate_session(result.state)
		assert paint_cumulative_offset(node, result.state, used) == position, id
		scope.finish()
		box := block_box_from_typed_layout_shallow(node, result.state, [6]f64{})
		assert box.x == expected[0] && box.y == expected[1], id
	}
}
