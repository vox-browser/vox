module layout

import dom
import html

fn test_svg_rect_fractional_user_units_preserve_chromium_geometry_and_libweb_layout_precision() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><svg width="140" height="100"><rect id="rect" x=".0665436" y="12.2" width="30.1483" height="29.9926" rx="1.6" ry=".8"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout_document_typed_in_viewport(document, 200, 120)
		element := document.get_element_by_id('rect')?
		bridge := element.as_node().layout_node()?
		node := unsafe { &Node(bridge.real_layout_handle()) }
		model := svg_geometry_element_model(node, element, CSSPixelSize.from_values(140, 100))
		for name, value in {
			'x':      .0665436
			'y':      12.2
			'width':  30.1483
			'height': 29.9926
			'rx':     1.6
			'ry':     .8
		} {
			expected := if policy == .chromium {
				f64(f32(value))
			} else {
				CSSPixels.nearest_value_for(value).to_double()
			}
			assert model.attributes[name].f64() == expected
		}
	}
}

fn test_chromium_svg_rect_css_overrides_resolve_percentage_calc_and_automatic_radii_without_layout_quantization() {
	mut document := html.parse_document('<!doctype html><style>#rect{x:10.1px;y:20.2px;width:calc(60% + .2px);height:29.9926px;rx:1.6px;ry:auto}</style><svg width="140" height="100"><rect id="rect" x="1" y="2" width="3" height="4" rx="5" ry="6"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 200, 120)
	mut element := document.get_element_by_id('rect')?
	bridge := element.as_node().layout_node()?
	node := unsafe { &Node(bridge.real_layout_handle()) }
	size := CSSPixelSize.from_values(140, 100)
	model := svg_geometry_element_model(node, element, size)
	for name, value in {
		'x':      10.1
		'y':      20.2
		'width':  84.2
		'height': 29.9926
		'rx':     1.6
		'ry':     1.6
	} {
		assert model.attributes[name].f64() == f64(f32(value))
	}
	element.set_attribute_value('style', 'width:30.1483px;rx:auto;ry:.8px')
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 200, 120)
	updated := element.as_node().layout_node()?
	updated_node := unsafe { &Node(updated.real_layout_handle()) }
	after := svg_geometry_element_model(updated_node, element, size)
	assert after.attributes['width'].f64() == f64(f32(30.1483))
	assert after.attributes['rx'].f64() == f64(f32(.8))
	assert after.attributes['ry'].f64() == f64(f32(.8))
}

fn test_chromium_svg_rect_display_list_keeps_fractional_path_endpoints() {
	mut document := html.parse_document('<!doctype html><svg width="140" height="100"><rect x=".0665436" y="12.2" width="30.1483" height="29.9926"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 200, 120)
	commands := display_list_commands(document.record_display_list() or { panic('missing display list') }).filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	data := commands[0].svg().path_data
	stride := compatibility_clip_path_segment_stride
	assert data[1] == f32(.0665436)
	assert data[2] == f32(12.2)
	assert data[stride + 1] == f32(f64(f32(.0665436)) + f64(f32(30.1483)))
	assert data[stride * 2 + 2] == f32(f64(f32(12.2)) + f64(f32(29.9926)))
}
