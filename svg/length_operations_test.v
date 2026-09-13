module svg

import math

fn assert_svg_length_close(actual f64, expected f64) {
	assert math.abs(actual - expected) < 0.000001
}

fn test_svg_length_scalar_parser_and_unit_type() {
	assert parse_svg_length_scalar('12')? == SvgLengthValue.number(12)
	assert parse_svg_length_scalar(' 25% ')? == SvgLengthValue.percentage(25)
	assert parse_svg_length_scalar('-2.5em')? == SvgLengthValue.length(-2.5, .ems)
	assert parse_svg_length_scalar('1Q')? == SvgLengthValue.length(1, .q)
	assert parse_svg_length_scalar('calc(1px + 2%)') == none
	assert parse_svg_length_scalar('12wat') == none

	assert SvgLength.create_detached(SvgLengthValue.number(1), false).unit_type() == 1
	assert SvgLength.create_detached(SvgLengthValue.percentage(1), false).unit_type() == 2
	assert SvgLength.create_detached(SvgLengthValue.length(1, .ems), false).unit_type() == 3
	assert SvgLength.create_detached(SvgLengthValue.length(1, .px), false).unit_type() == 5
	assert SvgLength.create_detached(SvgLengthValue.length(1, .q), false).unit_type() == 0
}

fn test_svg_length_resolves_absolute_percentage_and_relative_units() {
	assert_svg_length_close(SvgLength.create_detached(SvgLengthValue.length(1, .inches), false).resolved_value()!, 96)
	assert_svg_length_close(SvgLength.create_detached(SvgLengthValue.length(2.54, .cm), false).resolved_value()!, 96)
	assert_svg_length_close(SvgLength.create_detached(SvgLengthValue.percentage(25), false).resolved_value()!, 25)

	mut attached := SvgLength.create_detached(SvgLengthValue.length(2, .ems), false)
	attached.resolution_context = SvgLengthResolutionContext{
		has_associated_element: true
		viewport_width: 300
		viewport_height: 400
		font_size: 18
		root_font_size: 20
	}
	assert attached.resolved_value()! == 36
	attached.unit = .vw
	attached.value = 10
	assert attached.resolved_value()! == 30
	attached.unit = .vmin
	assert attached.resolved_value()! == 30

	detached_relative := SvgLength.create_detached(SvgLengthValue.length(1, .ems), false)
	if _ := detached_relative.resolved_value() {
		assert false
	} else {
		assert err.msg().contains('associated element')
	}
}

fn test_svg_length_setters_preserve_and_convert_units() {
	mut centimetres := SvgLength.create_detached(SvgLengthValue.length(2.54, .cm), false)
	centimetres.set_value(192)!
	assert_svg_length_close(centimetres.value_in_specified_units(), 5.08)
	assert centimetres.unit == .cm

	mut percentage_length := SvgLength.create_detached(SvgLengthValue.percentage(25), false)
	percentage_length.set_value(75)!
	assert percentage_length.value_in_specified_units() == 75
	assert percentage_length.value_as_string() == '75%'
	percentage_length.set_value_in_specified_units(12.5)!
	assert percentage_length.value_as_string() == '12.5%'

	percentage_length.new_value_specified_units(8, 2)!
	assert percentage_length.value_as_string() == '2in'
	percentage_length.convert_to_specified_units(5)!
	assert percentage_length.value_as_string() == '192px'
	if _ := percentage_length.new_value_specified_units(0, 1) {
		assert false
	} else {
		assert err.msg().contains('Unsupported')
	}
}

fn test_svg_length_string_and_read_only_algorithms() {
	mut length := SvgLength.create_detached(SvgLengthValue.number(0), false)
	length.set_value_as_string(' 12.5pt ')!
	assert length.value_as_string() == '12.5pt'
	length.set_value_as_string('calc(10px + 5%)')!
	assert length.unit_type() == 0
	assert length.value_in_specified_units() == 0
	assert length.value_as_string() == 'calc(10px + 5%)'
	if _ := length.set_value_as_string('auto') {
		assert false
	} else {
		assert err.msg().contains('SyntaxError')
	}

	mut readonly := SvgLength.create_detached(SvgLengthValue.number(1), true)
	if _ := readonly.set_value(2) {
		assert false
	} else {
		assert err.msg().contains('NoModificationAllowedError')
	}
}

fn test_svg_length_reflected_attribute_is_live_and_reserializes() {
	mut element := new_element('rect')
	element.attributes['width'] = '25%'
	element.attributes['_viewport_width'] = '320'
	mut reflected := SvgLength.create_reflected_attribute(element, 'width', .horizontal, SvgLengthValue.number(0), false)
	assert reflected.value_as_string() == '25%'
	assert reflected.resolved_value()! == 80

	element.attributes['width'] = '2cm'
	assert reflected.value_as_string() == '2cm'
	reflected.set_value_in_specified_units(3)!
	assert element.attributes['width'] == '3cm'

	element.attributes.delete('width')
	assert reflected.value_as_string() == '0'
}

fn test_svg_viewport_size_is_shared_by_geometry_and_reflected_lengths() {
	mut element := new_element('rect')
	element.attributes['_viewport_width'] = '300'
	element.attributes['_viewport_height'] = '120'
	element.attributes['width'] = '25%'
	viewport := element.viewport_size_for_percentage_resolution()
	assert viewport == ViewportSize{300, 120}
	horizontal := SvgLength.create_reflected_attribute(element, 'width', .horizontal, SvgLengthValue.number(0), false)
	assert horizontal.resolved_value()! == 75

	element.attributes['width'] = '50%'
	directionless := SvgLength.create_reflected_attribute(element, 'width', .unspecified, SvgLengthValue.number(0), false)
	assert_svg_length_close(directionless.resolved_value()!, math.sqrt((300.0 * 300.0 + 120.0 * 120.0) / 2.0) / 2.0)
}

fn test_animated_svg_length_retains_reflection_source_and_context() {
	mut element := new_element('rect')
	element.attributes['height'] = '50%'
	element.attributes['_viewport_height'] = '240'
	reflected := SvgLength.create_reflected_attribute(element, 'height', .vertical, SvgLengthValue.number(0), false)
	animated := AnimatedLength.create(reflected)
	assert animated.base_val().resolved_value()! == 120
	assert animated.anim_val().resolved_value()! == 120
	assert animated.anim_val().read_only

	element.attributes['height'] = '25%'
	assert animated.base_val().resolved_value()! == 60
	assert animated.anim_val().resolved_value()! == 60
}
