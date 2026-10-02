module layout

import css
import dom
import html

fn position_document(source string) !(&dom.Document, &html.WindowModel) {
	document := html.parse_document(source)
	window := html.WindowModel.create_top_level(document, none, 'scroll-position')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return document, window
}

fn test_scroll_into_view_viewport_uses_existing_offsets_and_exact_inline_end() {
	document, mut window :=
		position_document('<!doctype html><style>html,body{margin:0}body{width:1000px;height:1000px}#visible{position:absolute;left:100px;top:90px;width:20px;height:20px}#outside{position:absolute;left:300px;top:220px;width:20px;height:20px}</style><div id="visible"></div><div id="outside"></div>')!
	_ = window.scroll(html.ScrollToOptions{ left: 40, top: 70, behavior: .instant })
	visible := document.get_element_by_id('visible') or { panic('missing visible') }
	assert visible.get_bounding_client_rect() == dom.Rect{60, 20, 20, 20}
	assert dom.determine_the_scroll_into_view_position(visible, .nearest, .nearest,
		document.as_node()) == dom.CSSPixelPoint_{
		x_: 40
		y_: 70
	}
	outside := document.get_element_by_id('outside') or { panic('missing outside') }
	assert outside.get_bounding_client_rect() == dom.Rect{260, 150, 20, 20}
	assert dom.determine_the_scroll_into_view_position(outside, .end_, .end_, document.as_node()) == dom.CSSPixelPoint_{
		x_: 120
		y_: 140
	}
	assert dom.determine_the_scroll_into_view_position(outside, .center, .center,
		document.as_node()) == dom.CSSPixelPoint_{
		x_: 210
		y_: 180
	}
}

fn test_scroll_into_view_visual_viewport_and_document_element_percentage_padding() {
	document, mut window :=
		position_document('<!doctype html><style>html{scroll-padding:10% 20%}html,body{margin:0}body{width:1000px;height:1000px}#target{position:absolute;left:180px;top:140px;width:20px;height:20px;scroll-margin:3px 7px 5px 11px}</style><div id="target"></div>')!
	mut visual := window.visual_viewport() or { panic('missing visual viewport') }
	visual.scale_ = 2
	visual.offset_ = css.CSSPixelPoint.from_values(30, 20)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{40, 70, 200, 100})
	mutable_document.invalidate_scroll_state()
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect() == dom.Rect{140, 70, 20, 20}
	// Actual visual snapport: (50,25)-(110,65); current combined offset (70,90).
	assert dom.determine_the_scroll_into_view_position(target, .start, .start, document.as_node()) == dom.CSSPixelPoint_{
		x_: 149
		y_: 132
	}
	assert dom.determine_the_scroll_into_view_position(target, .end_, .end_, document.as_node()) == dom.CSSPixelPoint_{
		x_: 127
		y_: 120
	}
	assert voidptr(window.visual_viewport() or { panic('missing visual viewport') }) == voidptr(visual)
}

fn test_scroll_into_view_element_uses_transformed_padding_box_and_live_offset() {
	document, _ :=
		position_document('<!doctype html><style>html,body{margin:0}#scroller{position:absolute;left:40px;top:50px;width:100px;height:80px;padding:5px;border:3px solid;overflow:auto;transform:translate(15px,7px);scroll-padding:10% 20%}#content{position:relative;width:400px;height:400px}#target{position:absolute;left:180px;top:160px;width:20px;height:20px}</style><div id="scroller"><div id="content"><div id="target"></div></div></div>')!
	mut scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	_ = scroller.el_scroll(20, 30)
	assert scroller.el_scroll_offset() == dom.CSSPixelPoint_{
		x_: 20
		y_: 30
	}
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert scroller.get_bounding_client_rect() == dom.Rect{55, 57, 116, 96}
	assert target.get_bounding_client_rect() == dom.Rect{223, 195, 20, 20}
	// Actual transformed snapport: (80,69)-(146,141).
	assert dom.determine_the_scroll_into_view_position(target, .start, .start, scroller.as_node()) == dom.CSSPixelPoint_{
		x_: 163
		y_: 156
	}
	assert dom.determine_the_scroll_into_view_position(target, .end_, .end_, scroller.as_node()) == dom.CSSPixelPoint_{
		x_: 117
		y_: 104
	}
	_ = scroller.el_scroll(35, 45)
	assert dom.determine_the_scroll_into_view_position(target, .end_, .end_, scroller.as_node()) == dom.CSSPixelPoint_{
		x_: 117
		y_: 104
	}
}

fn test_scroll_into_view_nearest_keeps_covering_target_and_rejects_uncommitted_scroller() {
	document, _ :=
		position_document('<!doctype html><style>html,body{margin:0}#scroller{position:absolute;left:40px;top:20px;width:100px;height:60px;overflow:auto}#target{width:400px;height:400px}#hidden{display:none}</style><div id="scroller"><div id="target"></div></div><div id="hidden"></div>')!
	mut scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	_ = scroller.el_scroll(50, 70)
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect() == dom.Rect{-10, -50, 400, 400}
	assert dom.determine_the_scroll_into_view_position(target, .nearest, .nearest,
		scroller.as_node()) == dom.CSSPixelPoint_{
		x_: 50
		y_: 70
	}
	hidden := document.get_element_by_id('hidden') or { panic('missing hidden') }
	assert dom.determine_the_scroll_into_view_position(target, .start, .start, hidden.as_node()) == dom.CSSPixelPoint_{}
}

fn test_scroll_into_view_center_keeps_source_fixed_point_quotient() {
	document, _ :=
		position_document('<!doctype html><style>html,body{margin:0}#target{position:absolute;left:70px;top:50px;width:1.015625px;height:1.015625px}</style><div id="target"></div>')!
	target := document.get_element_by_id('target') or { panic('target') }
	assert target.get_bounding_client_rect() == dom.Rect{70, 50, 1.015625, 1.015625}
	assert dom.determine_the_scroll_into_view_position(target, .center, .center, document.as_node()) == dom.CSSPixelPoint_{
		x_: -29.5
		y_: 0.5
	}
}
