module layout

import dom
import html
import painting
import cpuraster

fn test_svg_pointer_geometry_matches_cssom_at_native_layout_scales() {
	for scale in [f64(1), 2] {
		for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
			mut document := html.parse_document('<!doctype html><svg id="svg" width="300" height="100"><rect id="target" x="10" y="10" width="40" height="40" fill="blue" stroke="none"/></svg>')
			document.set_layout_coordinate_scale(scale)
			document.set_display_device_pixel_ratio(scale)
			document.set_font_rendering_policy(policy)
			_ = layout_document_typed_in_viewport(document, 800, 600)
			target := document.get_element_by_id('target') or { panic('target') }
			viewport := document.get_element_by_id('svg') or { panic('svg') }
			bounds := viewport.get_bounding_client_rect()
			assert target.get_bounding_client_rect().width == 40, 'scale=${scale} policy=${policy} svg=${bounds} target=${target.get_bounding_client_rect()}'
			assert svg_pointer_hits(mut document, target, bounds.x + 30, bounds.y + 30), 'scale=${scale} policy=${policy} svg=${bounds} target=${target.get_bounding_client_rect()}'
			document.finalize()
		}
	}
}

fn svg_pointer_hits(mut document dom.Document, target &dom.Element, x f64, y f64) bool {
	hit := document.element_from_point(x, y) or { return false }
	return hit.as_node().unique_id() == target.as_node().unique_id()
}

fn test_svg_pointer_geometry_distinguishes_stroke_margins_and_unfilled_corners() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block}</style><svg width="240" height="100"><rect id="rect" x="10" y="10" width="40" height="40" fill="blue" stroke="blue" stroke-width="20"/><path id="triangle" d="M80 10H120V50Z"/><circle id="circle" cx="160" cy="30" r="20"/><path id="hole" d="M190 10H230V50H190Z M200 20H220V40H200Z" fill-rule="evenodd"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 260, 120)
	rect := document.get_element_by_id('rect') or { panic('rect') }
	triangle := document.get_element_by_id('triangle') or { panic('triangle') }
	circle := document.get_element_by_id('circle') or { panic('circle') }
	hole := document.get_element_by_id('hole') or { panic('hole') }
	assert svg_pointer_hits(mut document, rect, 30, 30)
	assert svg_pointer_hits(mut document, rect, 5, 5)
	assert !svg_pointer_hits(mut document, triangle, 90, 40)
	assert svg_pointer_hits(mut document, triangle, 110, 20)
	assert !svg_pointer_hits(mut document, circle, 142, 12)
	assert svg_pointer_hits(mut document, circle, 160, 30)
	assert !svg_pointer_hits(mut document, hole, 210, 30)
	assert svg_pointer_hits(mut document, hole, 195, 15)
}

fn test_svg_pointer_modes_use_unpainted_geometry_and_preserve_html_visibility() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block}</style><svg width="100" height="100"><rect id="target" x="10" y="10" width="40" height="40" fill="none" stroke="none" stroke-width="20" visibility="hidden" pointer-events="all"/></svg><div id="html" style="visibility:hidden;pointer-events:all;position:absolute;left:120px;top:0;width:50px;height:50px"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 120)
	mut target := document.get_element_by_id('target') or { panic('target') }
	html_element := document.get_element_by_id('html') or { panic('html') }
	for mode, hits in {
		'all':            [true, true]
		'fill':           [true, false]
		'stroke':         [false, true]
		'bounding-box':   [true, false]
		'painted':        [false, false]
		'visible':        [false, false]
		'visiblePainted': [false, false]
		'visibleFill':    [false, false]
		'visibleStroke':  [false, false]
		'auto':           [false, false]
		'none':           [false, false]
	} {
		target.set_attribute_value('pointer-events', mode)
		assert svg_pointer_hits(mut document, target, 30, 30) == hits[0], mode
		assert svg_pointer_hits(mut document, target, 5, 5) == hits[1], mode
	}
	target.set_attribute_value('visibility', 'visible')
	target.set_attribute_value('fill', 'transparent')
	target.set_attribute_value('stroke', 'transparent')
	target.set_attribute_value('opacity', '0')
	target.set_attribute_value('fill-opacity', '0')
	target.set_attribute_value('stroke-opacity', '0')
	target.set_attribute_value('pointer-events', 'visiblePainted')
	assert svg_pointer_hits(mut document, target, 30, 30)
	assert svg_pointer_hits(mut document, target, 5, 5)
	assert !svg_pointer_hits(mut document, html_element, 140, 20)
}

fn test_svg_text_pointer_regions_cover_unpainted_character_cells() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block}</style><svg width="200" height="120"><text id="target" x="30" y="70" font-family="monospace" font-size="40" fill="none" stroke="none" stroke-width="20" visibility="hidden" pointer-events="all">I</text></svg>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 220, 140)
	mut target := document.get_element_by_id('target') or { panic('text') }
	box := root.find_box(i64(target.as_node().unique_id())) or { panic('text box') }
	cells := box.svg_data.hit_test.text_cells or { panic('missing character cells') }
	mut unpainted := ?painting.Point(none)
	for row in 1 .. 10 {
		for column in 1 .. 10 {
			point := painting.Point{cells.x + cells.width * f64(column) / 10, cells.y + cells.height * f64(row) / 10}
			if !cpuraster.packed_path_hit_test(cpuraster.PackedPathHitTest{
				path:  box.svg_data.hit_test.path
				x:     f32(point.x)
				y:     f32(point.y)
				areas: 1
			}) {
				unpainted = point
			}
		}
	}
	point := unpainted or { panic('expected empty space in the character cell') }
	for mode in ['fill', 'stroke', 'all'] {
		target.set_attribute_value('pointer-events', mode)
		assert svg_pointer_hits(mut document, target, point.x, point.y), mode
		assert document.elements_from_point(point.x, point.y).any(it.as_node().unique_id() == target.as_node().unique_id())
	}
	assert !svg_pointer_hits(mut document, target, cells.x - 2, point.y)
	target.set_attribute_value('pointer-events', 'painted')
	assert !svg_pointer_hits(mut document, target, point.x, point.y)
	target.set_attribute_value('stroke', 'transparent')
	assert svg_pointer_hits(mut document, target, point.x, point.y)
}

fn test_svg_pointer_geometry_respects_clipping_and_retained_snapshots() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}svg{display:block}</style><svg width="100" height="100"><defs><clipPath id="cut"><rect width="30" height="100"/></clipPath></defs><rect id="target" x="10" y="10" width="40" height="40" fill="blue" stroke="blue" stroke-width="20" clip-path="url(#cut)"/></svg>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 120, 120)
	mut target := document.get_element_by_id('target') or { panic('target') }
	box := root.find_box(i64(target.as_node().unique_id())) or { panic('box') }
	old := box.svg_data
	assert svg_pointer_hits(mut document, target, 5, 5)
	assert !svg_pointer_hits(mut document, target, 45, 30)
	target.set_attribute_value('pointer-events', 'none')
	assert !svg_pointer_hits(mut document, target, 20, 20)
	assert old.hit_test.pointer_events == .auto_
	assert old.hit_test.has_fill
	assert old.hit_test.path.segments.len > 0
}
