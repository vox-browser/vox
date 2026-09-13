module svg

import math

fn test_geometry_elements() {
	line := Element{
		tag: 'line'
		attributes: {
			'x1': '10%'
			'y1': '20%'
			'x2': '50%'
			'y2': '80%'
		}
	}
	assert geometry_path(line, 200, 100).endpoints() == [Point{ x: 20, y: 20 },
		Point{ x: 100, y: 80 }]
	polygon := Element{
		tag: 'polygon'
		attributes: {
			'points': '0,0 10,0 10,10'
		}
	}
	assert geometry_path(polygon, 100, 100).instructions.last().type_ == .close_path
	circle := Element{
		tag: 'circle'
		attributes: {
			'cx': '50%'
			'cy': '50%'
			'r':  '10'
		}
	}
	assert geometry_path(circle, 200, 100).instructions.len == 5
	assert geometry_path(Element{
		tag: 'ellipse'
		attributes: {
			'rx': '0'
			'ry': '4'
		}
	}, 10, 10).instructions.len == 0
}

fn test_rect_corner_radius_defaulting_and_clamping() {
	rect := Element{
		tag: 'rect'
		attributes: {
			'x':      '10'
			'y':      '20'
			'width':  '100'
			'height': '40'
			'rx':     '80'
		}
	}
	path := geometry_path(rect, 200, 100)
	assert path.instructions[0].data == [60.0, 20.0]
	assert path.instructions[1].data == [60.0]
	assert path.instructions.last().type_ == .close_path
}

fn test_base_element_behavior_and_use_transform() {
	mut link := new_element('a')
	link.attributes['xlink:href'] = '#legacy'
	assert link.href() == '#legacy'
	link.attributes['href'] = '#modern'
	assert link.href() == '#modern'
	assert link.default_role() or { '' } == 'link'
	assert !new_element('defs').includes_in_accessibility_tree()
	assert new_element('a').default_role() or { '' } == 'generic'
	labelled_shape := Element{
		tag: 'circle'
		children: [Element{ tag: 'title', text: 'A circle' }]
	}
	assert labelled_shape.includes_in_accessibility_tree()
	assert labelled_shape.default_role() or { '' } == 'graphics-symbol'
	assert valid_use_reference_tag('circle')
	assert valid_use_reference_tag('script')
	assert valid_use_reference_tag('use')
	assert !valid_use_reference_tag('div')
	use := Element{
		tag: 'use'
		attributes: {
			'x':         '4'
			'y':         '5'
			'transform': 'scale(2)'
		}
	}
	matrix := element_transform(use)
	assert matrix.a == 2
	assert matrix.e == 8
	assert matrix.f == 10
}

fn test_mask_and_text_helpers() {
	area := resolve_masking_area(Rect{ x: 10, y: 20, width: 100, height: 50 })
	assert math.abs(area.x - -10) < 0.00001
	assert math.abs(area.y - 10) < 0.00001
	assert math.abs(area.width - 140) < 0.00001
	assert math.abs(area.height - 70) < 0.00001
	assert text_anchor('middle') or { TextAnchor.start } == .middle
	assert text_anchor('invalid') == none
}

fn test_fit_to_viewbox_viewport_and_text_positioning() {
	mut fit := FitToViewBox{}
	fit.update_attribute('viewBox', '0 0 640 480')
	assert fit.viewbox or { ViewBox{} }.width == 640
	assert !(fit.bindings_rect.nulled)
	fit.update_attribute('preserveAspectRatio', 'xMinYMax slice')
	assert fit.preserve_aspect_ratio.align == .x_min_y_max
	viewport := SvgViewport{
		fit: fit
		fallback_viewbox: ViewBox{
			width: 10
			height: 10
		}
	}
	assert viewport.active_viewbox() or { ViewBox{} }.height == 480
	positioning := text_positioning({
		'x':      '1'
		'dy':     '3'
		'rotate': '10'
	})
	assert positioning.x == [number(1)]
	assert positioning.dy == [number(3)]
	assert positioning.rotate == []
	assert positioning.apply_to_text_position(4, Point{}, Point{ x: 100, y: 100 }) == Point{ x: 1, y: 3 }
}

fn test_text_content_utf16_length_and_geometry_reference() {
	text := Element{
		tag: 'text'
		text: ' \tA😀'
		children: [Element{ tag: 'tspan', text: 'B' }]
	}
	assert text.text_contents() == 'A😀B'
	assert text.number_of_chars() == 4
	document := {
		'shape':     Element{
			tag: 'path'
		}
		'not-shape': Element{
			tag: 'g'
		}
	}
	assert resolve_geometry_reference('#shape', document) or { Element{} }.tag == 'path'
	assert resolve_geometry_reference('#not-shape', document) == none
}

fn test_text_path_start_offset_and_reflected_length() {
	mut text_path := Element{
		tag: 'textPath'
		attributes: {
			'startOffset': '25%'
		}
	}
	assert text_path.start_offset_for_path_length(240) == 60
	animated := text_path.start_offset()
	assert animated.base_val().value_in_specified_units() == 25
	assert animated.base_val().unit_type() == svg_lengthtype_percentage
	assert animated.anim_val().read_only

	mut base := animated.base_val()
	base.set_value_as_string('12')!
	assert text_path.attributes['startOffset'] == '12'
	assert text_path.start_offset_for_path_length(240) == 12
	assert new_element('textPath').start_offset_for_path_length(240) == 0
}

fn test_affine_transform_maps_rotated_rect_from_all_four_corners() {
	transform := AffineTransform{}.translated(20, 10).multiply(Transform{
		kind: .rotate
		values: [f64(90), 0, 0, 0, 0, 0]!
	}.matrix())
	mapped := transform.map_rect(Rect{ x: 0, y: 0, width: 30, height: 10 })
	assert math.abs(mapped.x - 10) < 0.0001
	assert math.abs(mapped.y - 10) < 0.0001
	assert math.abs(mapped.width - 10) < 0.0001
	assert math.abs(mapped.height - 30) < 0.0001
}
