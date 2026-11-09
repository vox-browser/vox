module layout

import html

fn test_tree_only_layout_can_publish_a_paint_snapshot_without_resizing_or_relaying_out() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="100" height="100"><rect id="target" width="50" height="50" fill="red"/></svg>')
	defer { document.finalize() }
	geometry := run_document_layout_for_tree_dump(document, 200, 100) or { panic('tree layout') }
	assert geometry.paint_tree.layout_handle == unsafe { nil }
	first := run_document_layout(document, 200, 100) or { panic('renderer layout') }
	assert voidptr(first.root) == voidptr(geometry.root)
	assert voidptr(first.state) == voidptr(geometry.state)
	assert first.paint_tree.layout_handle != unsafe { nil }
	assert first.paint_tree.paint_commands().filter(it.kind == 'draw_svg_path').len == 1
	assert display_list_commands(document.record_display_list() or { panic('recording') }).filter(it.kind == 'draw_svg_path').len == 1
	mut target := document.get_element_by_id('target') or { panic('target') }
	target.set_attribute_value('width', '60')
	second_geometry := run_document_layout_for_tree_dump(document, 200, 100) or { panic('updated tree') }
	second := run_document_layout(document, 200, 100) or { panic('updated renderer') }
	assert voidptr(second.root) == voidptr(second_geometry.root)
	assert voidptr(second.state) == voidptr(second_geometry.state)
	assert second.paint_tree.paint_commands().filter(it.kind == 'draw_svg_path').len == 1
}
