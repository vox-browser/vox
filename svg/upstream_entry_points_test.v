module svg

fn test_upstream_attribute_parser_and_value_factories() {
	mut parser := AttributeParser.from_string('10, 20')
	point := parser.parse_coordinate_pair() or { panic('coordinate pair') }
	assert point == Point{ x: 10, y: 20 }
	mut path_parser := AttributeParser.from_string('M0 0 L3 4')
	assert path_parser.parse_path_data().serialize() == 'M0 0 L3 4'
	mut transform := Transform.create()
	transform.set_rotate(90, 2, 3)
	assert transform.type_() == .rotate
	assert transform.angle() == 90
	assert NumberPercentage.create_percentage(25).resolve_relative_to(200) == 50
}

fn test_upstream_element_geometry_paint_and_filter_reflection() {
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

	mut blur := new_element('feGaussianBlur')
	blur.attributes['stdDeviation'] = '2 4'
	assert blur.std_deviation_x() == 2
	assert blur.std_deviation_y() == 4
	mut filter := new_element('filter')
	filter.children << blur
	graph := filter.gfx_filter()
	assert graph.nodes.len == 1
	assert graph.nodes[0].parameters['stdDeviationY'] == 4
}

fn test_upstream_gradient_pattern_and_component_transfer_slots() {
	gradient := LinearGradient{
		id: 'g'
		x1: percentage(10)
		y2: percentage(20)
	}
	resolved := gradient.linked_linear_gradient({ 'g': gradient }) or { panic('gradient') }
	assert gradient.start_x().value == 0.1
	assert resolved.x2.value == 1

	pattern := Pattern{
		id: 'p'
		width: number(12)
		height: number(8)
		has_children: true
	}
	assert pattern.pattern_width().value == 12
	assert pattern.pattern_content_element({ 'p': pattern })? == 'p'
	transfer := ComponentTransfer{
		type_: .linear
		slope: 2
		intercept: -0.5
	}
	assert transfer.type_from_attribute() == .linear
	assert transfer.slope() == 2
}

fn test_upstream_root_viewport_page_client_and_decoded_image() {
	mut viewport := SvgViewport{}
	viewport.set_fallback_view_box_for_svg_as_image(ViewBox{ width: 640, height: 480 })
	assert viewport.negotiate_natural_metrics() == Point{ x: 640, y: 480 }
	assert viewport.check_intersection(Rect{ width: 10, height: 10 }, Rect{ x: 5, y: 5, width: 10, height: 10 })
	assert viewport.create_svg_transform().type_() == .matrix

	mut client := SVGPageClient.create(7, true)
	assert client.is_svg_page_client()
	assert client.id() == 7
	assert client.is_headless()
	client.report_finished_handling_input_event(9)
	assert client.finished_inputs_ == [u64(9)]
	image := DecodedImageData.create(ViewBox{ width: 3, height: 2 }, none, none)
	assert image.surface().len == 24
}
