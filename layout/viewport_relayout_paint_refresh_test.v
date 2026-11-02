module layout

import dom
import html

fn viewport_relayout_matches_full_paint(mut document dom.Document) {
	retained := (record_retained_display_list(mut document) or { panic('missing retained paint') }).dump()
	mut result := document_layout_result(&document) or { panic('missing layout') }
	viewport := document.viewport_rect()
	refresh_document_paint_tree(&document, mut result, viewport.width, viewport.height)
	fresh := (record_retained_display_list(mut document) or { panic('missing full paint') }).dump()
	assert retained == fresh
}

fn test_viewport_relayout_preserves_current_paint_geometry_after_scroll_invalidation() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div style="height:600px;background:green">text</div>')
	defer { document.finalize() }
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
	storage := retain_document_paint_tree(document)
	$if prealloc { assert storage != unsafe { nil } }
	initial := document_layout_result(document) or { panic('missing initial layout') }
	children := initial.paint_tree.children.data
	defer { release_paint_tree(storage) }
	document.set_viewport_rect(dom.Rect{0, 25, 320, 200})
	document.set_needs_repaint()
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document) or { panic('missing scrolled layout') }
	assert voidptr(result.paint_tree_storage) == storage
	assert result.paint_tree.children.data == children
	assert document.viewport_rect().y == 25
	viewport_relayout_matches_full_paint(mut document)
}

fn test_viewport_relayout_uses_targeted_animation_refresh_and_matches_fresh_paint() {
	for sample in ['transform:translateX(100px)', 'opacity:0.5', 'background-color:blue'] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes change{to{${sample}}}#target{width:40px;height:30px;background:red;opacity:0.9;transform:translateX(0);animation:change 1s linear forwards}</style><div id="target"><span>text</span></div><svg width="20" height="20"><path d="M0 0H20V20H0Z" fill="green"/></svg>')
		defer { document.finalize() }
		enable_native_paint_tree_storage(document)
		_ = layout_document_typed_in_viewport(document, 320, 200)
		_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
		layout_handle := document.layout_engine_handle()
		for timestamp in [250.0, 500.0, 750.0] {
			storage := retain_document_paint_tree(document)
			$if prealloc { assert storage != unsafe { nil } }
			initial := document_layout_result(document) or { panic('missing initial layout') }
			children := initial.paint_tree.children.data
			document.update_animations_and_send_events(timestamp)
			_ = layout_document_typed_in_viewport(document, 320, 200)
			result := document_layout_result(document) or { panic('missing sampled layout') }
			assert document.layout_engine_handle() == layout_handle
			assert voidptr(result.paint_tree_storage) == storage, sample
			assert result.paint_tree.children.data == children, sample
			release_paint_tree(storage)
			viewport_relayout_matches_full_paint(mut document)
		}
	}
}

fn test_viewport_relayout_keeps_full_fallbacks_for_paint_geometry_and_resize_changes() {
	for change in ['box-shadow:2px 3px 4px blue', 'opacity:0.5', 'width:75px', 'display:none'] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div id="target" style="width:40px;height:30px;background:red">text</div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 320, 200)
		_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
		mut target := document.get_element_by_id('target') or { panic('missing target') }
		target.set_attribute_value('style', 'width:40px;height:30px;background:red;${change}')
		_ = layout_document_typed_in_viewport(document, 320, 200)
		assert document.layout_is_up_to_date()
		assert !document.needs_style_update_after_layout()
		if change == 'width:75px' { assert target.get_bounding_client_rect().width == 75 }
		viewport_relayout_matches_full_paint(mut document)
		_ = layout_document_typed_in_viewport(document, 480, 240)
		assert document.viewport_rect().width == 480
		assert document.viewport_rect().height == 240
		viewport_relayout_matches_full_paint(mut document)
	}
}
