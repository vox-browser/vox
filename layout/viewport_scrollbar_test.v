module layout

import dom
import html
import math

fn test_viewport_scrollbar_thumbs_follow_live_scroll_on_both_axes_without_relayout() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#content{width:1000px;height:1200px}</style><div id="content"></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'viewport-scrollbar')!
	_ = layout_document_typed_in_viewport(document, 200, 150)
	result := document_layout_result(document) or { panic('missing layout') }
	before := display_list_commands(document.record_display_list() or {
		panic('missing initial list')
	})
	initial_thumbs := before.filter(it.kind == 'fill_rounded_rect' && it.scrollbar_axis != '')
	assert initial_thumbs.len == 2
	assert result.paint_phase_cache_valid

	for offset in [[80.0, 140.0], [800.0, 1050.0], [0.0, 0.0]] {
		_ =
			window.scroll(html.ScrollToOptions{ left: offset[0], top: offset[1], behavior: .instant })
		assert document.viewport_rect().x == offset[0]
		assert document.viewport_rect().y == offset[1]
		commands := display_list_commands(document.record_display_list() or {
			panic('missing scrolled list')
		})
		thumbs := commands.filter(it.kind == 'fill_rounded_rect' && it.scrollbar_axis != '')
		assert thumbs.len == 2
		for index, thumb in thumbs {
			initial := initial_thumbs[index]
			assert thumb.width == initial.width && thumb.height == initial.height
			assert thumb.transform == initial.transform
			if thumb.scrollbar_axis == 'vertical' {
				assert math.abs(thumb.y - initial.y -
					offset[1] * initial.scrollbar_thumb_travel_ratio) < 0.001
				assert thumb.x == initial.x
			} else {
				assert math.abs(thumb.x - initial.x -
					offset[0] * initial.scrollbar_thumb_travel_ratio) < 0.001
				assert thumb.y == initial.y
			}
		}
		assert voidptr(document_layout_result(document) or { panic('missing retained layout') }) == voidptr(result)
		assert result.paint_phase_cache_valid
	}
}

fn test_viewport_and_element_scrollbars_read_their_own_scroll_positions() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:100px;overflow:auto}#inner{height:500px}#remainder{height:900px}</style><div id="scroller"><div id="inner"></div></div><div id="remainder"></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'separate-scrollbars')!
	root := layout_document_typed_in_viewport(document, 200, 150)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('missing scroller paintable') }
	assert paintable.set_scroll_offset(dom.CSSPixelPoint_{ y_: 60 })
	_ = window.scroll(html.ScrollToOptions{ top: 120, behavior: .instant })
	root_overlay := root.overlay or { panic('missing viewport overlay') }
	inner := root.find_box(i64(scroller.as_node().unique_id())) or { panic('missing inner box') }
	inner_overlay := inner.overlay or { panic('missing inner overlay') }
	assert root.current_scroll_offset(root_overlay).y == 120
	assert inner.current_scroll_offset(inner_overlay).y == 60
	// The first recording must use the live offset, even if layout ran at zero.
	thumbs := root.paint_commands().filter(it.kind == 'fill_rounded_rect'
		&& it.scrollbar_axis == 'vertical')
	assert thumbs.len == 2
	assert thumbs.any(it.scrollbar_recorded_scroll_offset == 120)
	assert thumbs.any(it.scrollbar_recorded_scroll_offset == 60)
}
