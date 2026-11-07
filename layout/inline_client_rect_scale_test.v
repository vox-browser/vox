module layout

import dom
import html

const inline_client_rect_markup = '<!doctype html><style>html,body{margin:0}
p{position:absolute;left:50px;top:300px;margin:0;font:16px/20px sans-serif}
#scroller{position:absolute;left:0;top:400px;width:200px;height:40px;overflow:auto;font:16px/20px sans-serif}
#tall{height:100px}</style>
<p>text <span><a id="link" href="#">inline link<span id="count"> (1 reply)</span></a></span></p>
<div id="scroller"><div id="tall"></div><span id="inner">inside</span></div>'

fn inline_client_rect(document &dom.Document, id string) dom.Rect {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

fn inline_client_rects_at_scale(scale f64) (dom.Rect, dom.Rect, dom.Rect, dom.Rect) {
	mut document := html.parse_document(inline_client_rect_markup)
	defer { document.finalize() }
	// The browser lays out with Chromium's font policies.
	document.set_font_size_keyword_policy(.chromium)
	document.set_font_rendering_policy(.chromium)
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	document.set_layout_coordinate_scale(scale)
	install_document_layout_hook(document)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	link := inline_client_rect(document, 'link')
	count := inline_client_rect(document, 'count')
	inner := inline_client_rect(document, 'inner')
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	mut paintable := scroller.paintable_box() or { panic('scroller paintable') }
	paintable.set_scroll_offset_without_snapping(dom.CSSPixelPoint_{0, 30})
	scrolled := inline_client_rect(document, 'inner')
	return link, count, inner, scrolled
}

fn near_css_pixel(a f64, b f64) bool {
	return a - b < 1 && b - a < 1
}

// Old Reddit's driver computed clicks from an inline link's rectangle; device
// pixel layout reported twice its CSS position, so the click missed the link.
fn test_inline_client_rects_are_css_pixels_in_device_pixel_layout() {
	css_link, css_count, css_inner, css_scrolled := inline_client_rects_at_scale(1)
	device_link, device_count, device_inner, device_scrolled := inline_client_rects_at_scale(2)
	// The inline box's content area sits inside the 20px line box at top 300.
	assert css_link.y >= 300 && css_link.y + css_link.height <= 320, '${css_link}'
	assert css_link.x > 50 && css_link.x < 120, '${css_link}'
	assert css_count.x > css_link.x && css_count.x + css_count.width <= css_link.x + css_link.width + 1
	for pair in [[css_link, device_link], [css_count, device_count], [css_inner, device_inner],
		[css_scrolled, device_scrolled]] {
		assert near_css_pixel(pair[0].x, pair[1].x), '${pair}'
		assert near_css_pixel(pair[0].y, pair[1].y), '${pair}'
		assert near_css_pixel(pair[0].width, pair[1].width), '${pair}'
		assert near_css_pixel(pair[0].height, pair[1].height), '${pair}'
	}
}

// An inline box is painted in its container's descendants context, so the
// container's scroll offset moves its client rectangle.
fn test_inline_client_rects_follow_their_scroll_container() {
	for scale in [1.0, 2.0] {
		_, _, inner, scrolled := inline_client_rects_at_scale(scale)
		assert inner.y >= 500 && inner.y + inner.height <= 520, 'scale ${scale}: ${inner}'
		assert scrolled.y == inner.y - 30, 'scale ${scale}: ${scrolled}'
		assert scrolled.x == inner.x
	}
}
