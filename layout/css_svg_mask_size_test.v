module layout

import html
import http
import loader
import math
import painting

fn svg_mask_sizing_geometry(extra string, chromium bool) []f64 {
	address := 'https://css-mask-sizing.test/menu.svg'
	mut resources := if loader.is_initialized() {
		loader.ResourceLoader.the()
	} else {
		loader.initialize()
	}
	resources.register_network_response(address, loader.NetworkResponse{
		data:    '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="10" viewBox="0 0 12 10"><path fill="white" d="M0 0h12v1H0zm0 9h12v1H0zm0-6h12v1H0zm0 3h12v1H0z"/></svg>'.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{margin:22px 0 0 18px;width:16px;height:16px;background:white;mask-image:url("${address}");mask-size:contain;mask-position:center;mask-repeat:no-repeat;${extra}}</style><div id="target"></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	root := layout_document_typed_in_viewport(document, 100, 80)
	element := document.get_element_by_id('target') or { panic('missing target') }
	box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing box') }
	mask := box.clips().svg_mask or { panic('missing CSS mask') }
	assert mask.operations.len == 1
	operation := mask.operations[0]
	return [operation.transform.a, operation.transform.d, operation.transform.e, operation.transform.f]
}

fn assert_svg_mask_geometry(extra string, expected []f64) {
	actual := svg_mask_sizing_geometry(extra, true)
	for i, value in expected {
		assert math.abs(actual[i] - value) < 0.00001, '${extra}: component ${i}: actual ${actual[i]}, expected ${value}'
	}
}

fn test_css_svg_mask_contain_scales_a_non_square_image_into_the_centered_tile() {
	assert_svg_mask_geometry('', [1.3, 1.3, 18.2, 24.0])
	assert_svg_mask_geometry('width:24px', [19.0 / 12, 19.0 / 12, 21.0, 22.0 + 1.0 / 12])
	assert_svg_mask_geometry('height:24px', [1.3, 1.3, 18.2, 28.0])
	assert_svg_mask_geometry('margin-left:18.5px;margin-top:22.25px', [1.3, 1.3, 19.2, 24.0])
}

fn test_css_svg_masks_honor_natural_explicit_and_percentage_image_sizes() {
	assert_svg_mask_geometry('mask-size:auto', [1.0, 1.0, 20.0, 25.0])
	assert_svg_mask_geometry('mask-size:12px 10px;mask-position:right bottom', [1.0, 1.0, 22.0,
		28.0])
	assert_svg_mask_geometry('mask-size:75% auto;mask-position:25% 75%', [1.0, 1.0, 19.0, 27.0])
}

fn test_css_svg_cover_keeps_fractional_layout_before_rounding_the_recording() {
	assert_svg_mask_geometry('mask-size:cover', [19.0 / 12, 19.1875 / 12, 16.0, 22.0 + 1.0 / 192])
}

fn test_libweb_svg_mask_tiles_keep_their_fractional_sizing_and_position() {
	actual := svg_mask_sizing_geometry('', false)
	expected := [13.328125 / 10, 13.328125 / 10, 18.0, 23.328125]
	for i, value in expected {
		assert math.abs(actual[i] - value) < 0.00001, 'LibWeb component ${i}: actual ${actual[i]}, expected ${value}'
	}
}

fn test_zero_size_css_svg_mask_keeps_a_transparent_scope() {
	mut document := html.parse_document('<!doctype html><style>#target{width:16px;height:16px;background:red;mask-image:url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'12\' height=\'10\' viewBox=\'0 0 12 10\'%3E%3Cpath d=\'M0 0H12V10H0Z\'/%3E%3C/svg%3E");mask-size:0 0;mask-repeat:no-repeat}</style><div id="target"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 100, 80)
	element := document.get_element_by_id('target') or { panic('missing target') }
	box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing target box') }
	mask := box.clips().svg_mask or { panic('zero size must retain the mask') }
	assert mask.operations.len > 0
	for operation in mask.operations {
		assert !operation.has_fill || operation.fill_opacity == 0 || operation.fill_color.a == 0
	}
	commands := display_list_commands(document.record_display_list() or { panic('missing masked paint') })
	assert commands.any(it.kind == 'begin_svg_mask_layer')
	assert commands.any(it.kind == 'end_svg_mask_layer')
}

fn test_css_svg_mask_tile_mapping_keeps_viewport_clipping_and_filter_fallbacks() {
	operation := painting.SVGMaskPaintOperation{
		kind:     .path
		has_fill: true
		path:     painting.ClipPathVisualData{
			segments: [
				painting.ClipPathSegment{ kind: .move_to, point: painting.Point{0, 0} },
				painting.ClipPathSegment{ kind: .line_to, point: painting.Point{12, 0} },
				painting.ClipPathSegment{ kind: .line_to, point: painting.Point{12, 10} },
				painting.ClipPathSegment{ kind: .close_path },
			]
			polygons: [[painting.Point{0, 0}, painting.Point{12, 0}, painting.Point{12, 10}]]
		}
	}
	assert css_svg_mask_operations_fit_image([operation], 12, 10)
	assert !css_svg_mask_operations_fit_image([operation], 10, 10)
	assert !css_svg_mask_operations_fit_image([painting.SVGMaskPaintOperation{
		...operation
		transform: painting.Affine{ e: -1 }
	}], 12, 10)
	assert !css_svg_mask_operations_fit_image([painting.SVGMaskPaintOperation{
		...operation
		has_stroke:   true
		stroke_width: 1
	}], 12, 10)
	assert !css_svg_mask_operations_fit_image([painting.SVGMaskPaintOperation{ kind: .begin_filter }], 12, 10)
	assert !css_svg_mask_operations_fit_image([painting.SVGMaskPaintOperation{ kind: .image }], 12, 10)
}
