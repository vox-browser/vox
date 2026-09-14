module svg

fn test_upstream_attribute_parser_and_value_factories() {
	mut parser := AttributeParser.from_string('10, 20')
	point := parser.parse_coordinate_pair() or { panic('coordinate pair') }
	assert point == Point{ x: 10, y: 20 }
	mut path_parser := AttributeParser.from_string('M0 0 L3 4')
	assert path_parser.parse_path_data().serialize() == 'M 0 0 L 3 4'
	mut transform := Transform.create()
	transform.set_rotate(90, 2, 3)
	assert transform.type_() == .unknown
	assert transform.angle() == 0
	assert NumberPercentage.create_percentage(25).resolve_relative_to(200) == 50
	assert SvgLength.from_length_percentage(percentage(25)).value == 25
}

fn test_upstream_attribute_parser_consumes_one_path_production_at_a_time() {
	mut parser := AttributeParser.from_string('M0 0 1 1 L3 4 A5 6 30 0 1 7 8')
	first := parser.parse_drawto()
	assert first.serialize() == 'M 0 0 L 1 1'
	assert parser.ch() == `L`
	second := parser.parse_drawto()
	assert second.serialize() == 'M 0 0 L 1 1 L 3 4'
	assert parser.ch() == `A`
	third := parser.parse_drawto()
	assert third.serialize() == 'M 0 0 L 1 1 L 3 4 A 5 6 30 0 1 7 8'
	assert parser.done()
}

fn test_upstream_element_geometry_paint_and_filter_reflection() {
	switch_element := new_element('switch')
	assert switch_element.is_svg_switch_element()
	assert switch_element.is_svg_graphics_element()
	assert new_element('clipPath').is_svg_clip_path_element()
	assert new_element('linearGradient').is_svg_gradient_element()
	assert new_element('radialGradient').is_svg_gradient_element()
	assert !new_element('stop').is_svg_gradient_element()
	assert new_element('image').is_svg_image_element()
	assert new_element('pattern').is_svg_pattern_element()

	mut rect := new_element('rect')
	rect.attributes['x'] = '10'
	rect.attributes['y'] = '20'
	rect.attributes['width'] = '30'
	rect.attributes['height'] = '40'
	rect.attributes['fill'] = '#ff0000'
	rect.attributes['stroke'] = 'blue'
	rect.attributes['stroke-width'] = '3'
	assert rect.get_b_box() == Rect{ x: 10, y: 20, width: 30, height: 40 }
	assert rect.fill_paint_style()?.color == u32(0xffff0000)
	assert rect.visible_stroke_width() == 3
	rect.attributes['stroke-dasharray'] = '2 3 4'
	assert rect.stroke_dasharray() == [f32(2), 3, 4, 2, 3, 4]
	rect.attributes['stroke-dasharray'] = '0 0'
	assert rect.stroke_dasharray() == []
	rect.attributes['rx'] = '0'
	rect.attributes['ry'] = '4'
	assert rect.calculate_used_corner_radius_values(100, 100) == Point{ x: 0, y: 4 }
	assert new_element('line').x2() == number(0)
	assert new_element('circle').r() == number(0)
	assert new_element('radialGradient').r() == percentage(50)

	mut blur := new_element('feGaussianBlur')
	blur.attributes['stdDeviation'] = '2 4'
	assert blur.std_deviation_x() == 2
	assert blur.std_deviation_y() == 4
	mut filter := new_element('filter')
	filter.children << blur
	graph := filter.gfx_filter()
	assert graph.nodes.map(it.kind) == ['color-space-conversion', 'blur', 'color-space-conversion']
	assert graph.nodes[1].parameters['radius_y'] == 4
}

fn test_upstream_gradient_pattern_and_component_transfer_slots() {
	gradient := LinearGradient{
		id: 'g'
		x1: percentage(10)
		y2: percentage(20)
	}
	resolved := gradient.linked_linear_gradient({
		'g': gradient
	}) or { panic('gradient') }
	assert gradient.start_x().value == 0.1
	assert resolved.x2.value == 1
	radial := LinkedRadialGradient{ fx: percentage(20), fy: percentage(30) }
	assert radial.start_circle_x() == percentage(20)
	assert radial.start_circle_y() == percentage(30)

	pattern := Pattern{
		id: 'p'
		width: number(12)
		height: number(8)
		has_children: true
	}
	assert pattern.pattern_width().value == 12
	assert pattern.pattern_content_element({
		'p': pattern
	})? == 'p'
	transfer := ComponentTransfer{
		type_: .linear
		slope: 2
		intercept: -0.5
	}
	assert transfer.type_from_attribute() == .linear
	assert transfer.slope() == 2
}

fn test_upstream_root_viewport_page_client_and_decoded_image() {
	mut viewport := SvgViewport{ width: 640, height: 480 }
	viewport.set_fallback_view_box_for_svg_as_image(ViewBox{ width: 640, height: 480 })
	metrics := viewport.negotiate_natural_metrics()
	assert metrics.width? == 640
	assert metrics.height? == 480
	assert metrics.aspect_ratio? == 4.0 / 3.0
	assert !viewport.check_intersection(Rect{ width: 10, height: 10 }, Rect{ x: 5, y: 5, width: 10, height: 10 })
	assert viewport.create_svg_transform().type_() == .unknown
	mut first_number := viewport.create_svg_number()
	second_number := viewport.create_svg_number()
	assert first_number.value == 0
	first_number.set_value(12.5)!
	assert first_number.value == 12.5
	assert second_number.value == 0
	assert !first_number.read_only()

	mut client := SVGPageClient.create(7, true)
	assert client.is_svg_page_client()
	assert client.is_headless()
	client.report_finished_handling_input_event(9)
	assert !client.is_connection_open()
	image := DecodedImageData.create(ViewBox{ width: 3, height: 2 }, none, none)
	assert image.intrinsic_width() == none
	assert image.intrinsic_aspect_ratio()? == 1.5
	assert image.surface().len == 0
}
