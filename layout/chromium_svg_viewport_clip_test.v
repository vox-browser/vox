module layout

import html
import painting

fn test_chromium_svg_viewports_keep_fractional_overflow_clip_edges() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg id="icon" width="15.390625" height="15.390625" style="position:absolute;left:24.625px;top:12.296875px"><path d="M0 0H16V16H0Z"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = run_document_layout(document, 300, 150) or { panic('layout') }
	element := document.get_element_by_id('icon') or { panic('icon') }
	handle := element.as_node().layout_node() or { panic('layout node') }
	node := unsafe { &Node(handle.real_layout_handle()) }
	box := BlockBox{ layout_handle: node }
	rect := LayoutRect{24.625, 12.296875, 15.390625, 15.390625}
	clip := compatibility_clip_visual_data(&box, rect, BoxRadii{})
	assert compatibility_clip_layout_rect(clip) == rect
	assert clip.contains_layout_point(painting.Point{25, 27.5})
	assert !clip.contains_layout_point(painting.Point{25, 27.75})
}
