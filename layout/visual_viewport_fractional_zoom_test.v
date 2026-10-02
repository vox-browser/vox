module layout

import css
import dom
import html

fn fractional_zoom_owner() !(&dom.Document, &html.WindowModel) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{height:1000px;width:1000px}</style><body></body>')
	window := html.WindowModel.create_top_level(document, none, 'fractional-zoom')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return document, window
}

fn test_visual_viewport_zoom_retains_fractional_focal_points_and_previous_fractional_offsets() {
	mut document, mut window := fractional_zoom_owner()!
	mut visual := window.visual_viewport() or { panic('VisualViewport') }
	facade := document.visual_viewport()
	visual.zoom(css.CSSPixelPoint.from_values(1.25, 2.25), 1)
	assert facade.scale() == 2
	assert facade.offset_left() == 0.625 && facade.offset_top() == 1.125
	assert facade.width() == 100 && facade.height() == 50
	assert document.pending_scroll_events.len == 1
	visual.zoom(css.CSSPixelPoint.from_values(1.5, 2.25), 0.5)
	assert facade.scale() == 3
	assert facade.offset_left() == 0.875 && facade.offset_top() == 1.5
	assert document.pending_scroll_events.len == 1
	assert voidptr(document.pending_scroll_events[0].event_target?) == voidptr(visual.event_target())
	document.run_the_scroll_steps()
	visual.zoom(css.CSSPixelPoint.from_values(1.5, 2.25), 0)
	assert facade.offset_left() == 0.875 && facade.offset_top() == 1.5
	assert document.pending_scroll_events.len == 0
}

fn test_visual_viewport_fractional_pinch_clamps_scale_and_offset_to_actual_owner_dimensions() {
	mut document, mut window := fractional_zoom_owner()!
	mut visual := window.visual_viewport() or { panic('VisualViewport') }
	visual.zoom(css.CSSPixelPoint.from_values(9999.25, 9999.75), 10)
	assert visual.scale() == 5
	assert visual.offset_left() == 160 && visual.offset_top() == 80
	assert visual.width() == 40 && visual.height() == 20
	assert document.viewport_rect() == dom.Rect{0, 0, 200, 100}
	visual.zoom(css.CSSPixelPoint.from_values(9999.25, 9999.75), -100)
	assert visual.scale() == 1 && visual.offset_left() == 0 && visual.offset_top() == 0
	assert document.pending_scroll_events.len == 1
}
