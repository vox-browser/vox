module layout

import css
import dom
import html

fn device_layout_used(result &DocumentLayoutResult, element &dom.Element) &UsedValues {
	bridge := element.as_node().layout_node() or { panic('missing layout') }
	node := unsafe { &Node(bridge.layout_handle) }
	return result.state.try_get(node.as_node_with_style() or { panic('missing style') }) or { panic('missing geometry') }
}

fn test_device_layout_keeps_css_viewport_and_media_queries_logical() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#a{font:17px Arial;width:6.4px;height:10px} @media(min-width:1000px){#a{width:100px}}</style><div id=a></div><ul id=list><li>item</li></ul>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	assert document.viewport_rect().width == 800
	viewport := result.root.as_node_with_style() or { panic('viewport') }
	assert (result.state.try_get(viewport) or { panic('viewport geometry') }).content_width().to_double() == 1600
	a := document.get_element_by_id('a') or { panic('a') }
	used := device_layout_used(&result, a)
	assert used.content_width().to_double() == 12.796875
	assert used.content_height().to_double() == 20
	assert a.client_height() == 10
	assert a.get_bounding_client_rect().width == 6.3984375
	assert html.html_element_offset_width(unsafe { &dom.HTMLElement(a) }) == 6
	raw := css.computed_properties_for_element(a) or { panic('style') }
	assert raw.resolved_font_size_px() == 17
	assert raw.layout_coordinate_scale() == 1
	resolved := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(a, none))
	assert resolved.get_property_value('height') == '10px'
	resolved_width := resolved.get_property_value('width').all_before('px').f64()
	assert resolved_width > 6.39843 && resolved_width < 6.39845
	list := document.get_element_by_id('list') or { panic('list') }
	assert device_layout_used(&result, list).padding_left.to_double() == 80
}

fn test_device_layout_visual_root_scales_fixed_boxes_and_scroll_offsets() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#flow{width:40px;height:20px;margin:10px}#fixed{position:fixed;right:0;bottom:0;width:20px;height:15px}body{height:1000px}</style><div id=flow></div><div id=fixed></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	document.set_viewport_rect(dom.Rect{0, 40, 800, 600})
	flow := document.get_element_by_id('flow') or { panic('flow') }
	fixed := document.get_element_by_id('fixed') or { panic('fixed') }
	assert flow.get_bounding_client_rect() == dom.Rect{10, -30, 40, 20}
	assert fixed.get_bounding_client_rect() == dom.Rect{780, 585, 20, 15}
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	assert commands.len > 0
}

fn test_device_layout_live_styles_and_scale_changes_rebuild_the_correct_units() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div id=a style="width:6.4px;height:10px"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	mut a := document.get_element_by_id('a') or { panic('a') }
	a.set_attribute_value('style', 'width:9.2px;height:11px')
	document.update_layout(.debugging)
	assert a.get_bounding_client_rect().width == 9.1953125
	assert a.client_height() == 11
	document.set_layout_coordinate_scale(1)
	document.update_layout(.debugging)
	assert a.get_bounding_client_rect().width == 9.1875
	assert a.client_height() == 11
}

fn test_device_layout_natural_image_sizes_and_replaced_defaults_scale_once() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><img id=a src="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%2214%22 height=%227%22/%3E">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	a := document.get_element_by_id('a') or { panic('a') }
	assert device_layout_used(&result, a).content_width().to_double() == 28
	assert a.get_bounding_client_rect().width == 14
	assert a.get_bounding_client_rect().height == 7
	image := unsafe { &dom.HTMLImageElement(a) }
	assert html.html_image_element_width(image) == 14
	assert html.html_image_element_height(image) == 7
	assert html.html_image_element_x(image) == int(a.get_bounding_client_rect().x)
	assert html.html_image_element_y(image) == int(a.get_bounding_client_rect().y)
	box := Box.new(document, none, css.ComputedProperties.new())
	size := compute_replaced_size(box, AvailableSpace{
		width:  AvailableSize.make_indefinite()
		height: AvailableSize.make_indefinite()
	})
	assert size.width().to_double() == 600
	assert size.height().to_double() == 300
}

fn test_device_layout_dom_scroll_bounds_and_paint_offsets_remain_css_pixels() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroll{overflow:auto;width:100px;height:50px}#inner{width:300px;height:200px;background:red}</style><div id=scroll><div id=inner></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	mut scroller := document.get_element_by_id('scroll') or { panic('scroll') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	mut paintable := scroller.paintable_box() or { panic('paintable') }
	assert scroller.client_width() == 100
	assert scroller.client_height() == 50
	assert scroller.scroll_width() == 300
	assert scroller.scroll_height() == 200
	assert paintable.maximum_scroll_offset() == dom.CSSPixelPoint_{200, 150}
	paintable.set_scroll_offset_without_snapping(dom.CSSPixelPoint_{25, 30})
	assert inner.get_bounding_client_rect() == dom.Rect{-25, -30, 300, 200}
}

fn test_device_layout_compositor_style_refresh_preserves_the_visual_root() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#a{width:40px;height:20px;transform:translateX(10px);background:red}</style><div id=a></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	mut a := document.get_element_by_id('a') or { panic('a') }
	assert a.get_bounding_client_rect().x == 10
	_ = document.record_display_list() or { panic('paint') }
	a.set_attribute_value('style', 'transform:translateX(20px);background:blue')
	document.update_layout(.debugging)
	assert a.get_bounding_client_rect() == dom.Rect{20, 0, 40, 20}
}

fn test_device_layout_scroll_snap_crosses_the_css_boundary_once() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroll{overflow:auto;width:100px;height:50px;scroll-snap-type:y mandatory}#scroll>div{height:50px;scroll-snap-align:start}</style><div id=scroll><div></div><div></div><div></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	scroller := document.get_element_by_id('scroll') or { panic('scroll') }
	mut paintable := scroller.paintable_box() or { panic('paintable') }
	paintable.set_scroll_offset(dom.CSSPixelPoint_{0, 40})
	assert paintable.scroll_offset().y() == 50
	assert paintable.maximum_scroll_offset().y() == 100
}

fn test_device_layout_table_and_button_wrappers_inherit_physical_fonts_once() {
	mut document := html.parse_document('<!doctype html><style>body{font:17px Arial}button{font:inherit}</style><button id=button>button</button><table id=table><tr><td>cell</td></tr></table>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	for id in ['button', 'table'] {
		element := document.get_element_by_id(id) or { panic(id) }
		bridge := element.as_node().layout_node() or { panic('layout node') }
		node := unsafe { &Node(bridge.layout_handle) }
		node.for_each_in_inclusive_subtree(fn (child &Node) dom.TraversalDecision {
			if styled := child.as_node_with_style() {
				assert styled.computed_values().resolved_font_size_px() == 34
				assert styled.computed_values().layout_coordinate_scale() == 2
			}
			return .@continue
		})
		if parent := node.parent() {
			if parent.is_table_wrapper() {
				assert parent.computed_values().resolved_font_size_px() == 34
				assert parent.computed_values().layout_coordinate_scale() == 2
			}
		}
	}
}
