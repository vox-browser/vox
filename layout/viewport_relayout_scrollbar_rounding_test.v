module layout

import dom
import html

fn test_viewport_relayout_keeps_fresh_scrollbar_rounding_on_both_axes_and_nested_scrollports() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:80px;overflow:auto}#inner{width:600px;height:500px}#rest{width:1000px;height:900px}</style><div id="scroller"><div id="inner">nested</div></div><div id="rest">remainder</div>')
	defer { document.finalize() }
	mut window := html.WindowModel.create_top_level(document, none, 'relayout-scrollbars')!
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = document.record_display_list() or { panic('missing initial list') }
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scrollport') }
	for offset in [[10.25, 20.5], [80.5, 140.75], [0.0, 0.0]] {
		initial := document_layout_result(document) or { panic('missing retained layout') }
		children := initial.paint_tree.children.data
		storage := retain_document_paint_tree(document)
		_ = window.scroll(html.ScrollToOptions{left:offset[0],top:offset[1],behavior:.instant})
		_ = paintable.set_scroll_offset(dom.CSSPixelPoint_{x_:offset[0],y_:offset[1]})
		_ = layout_document_typed_in_viewport(document, 320, 200)
		mut result := document_layout_result(document) or { panic('missing scrolled layout') }
		assert result.paint_tree.children.data == children
		assert voidptr(result.paint_tree_storage) == storage
		release_paint_tree(storage)
		retained := (document.record_display_list() or { panic('missing retained list') }).dump()
		refresh_document_paint_tree(document, mut result, 320, 200)
		fresh := (document.record_display_list() or { panic('missing full list') }).dump()
		assert retained == fresh
	}
}
