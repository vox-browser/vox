module layout

import dom
import html

fn test_initial_resource_style_preparation_preserves_scroll_and_later_geometry() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:50vw;height:20px;background:url(https://background.test/shape.svg)}</style><div id="target"></div>')
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{7, 11, 100, 100})
	prepare_initial_resource_styles(document, 320, 200)
	viewport := document.viewport_rect()
	assert viewport.x == 7 && viewport.y == 11
	assert viewport.width == 320 && viewport.height == 200
	assert document.layout_root == unsafe { nil }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	target := document.get_element_by_id('target')?
	result := document_layout_result(document)?
	box := result.paint_tree.find_box(i64(target.as_node().unique_id()))?
	assert box.width == 160 && box.height == 20
}
