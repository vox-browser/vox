module css

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn property_export_scalar_values() []StyleValue {
	return [
		StyleValue(KeywordStyleValue.create(.auto)),
		StyleValue(LengthStyleValue.create(Length.new(1.25, .em))),
		StyleValue(NumberStyleValue.create(0.375)),
		StyleValue(IntegerStyleValue.create(-17)),
		StyleValue(AngleStyleValue.create(Angle.make_degrees(45))),
		StyleValue(PercentageStyleValue.create(Percentage.new(12.5))),
		StyleValue(FlexStyleValue.create(Flex.make_fr(2))),
		StyleValue(FrequencyStyleValue.create(Frequency.make_hertz(440))),
		StyleValue(ResolutionStyleValue.create(Resolution.make_dots_per_pixel(2))),
		StyleValue(TimeStyleValue.create(Time.make_seconds(0.25))),
		StyleValue(ColorStyleValue.create(Color.rgba(12, 34, 56, 78))),
		StyleValue(DisplayStyleValue.create(Display.from_outside_inside(.inline_, .flex))),
		StyleValue(RepeatStyleStyleValue.create(.repeat, .no_repeat)),
		StyleValue(ScrollbarGutterStyleValue.create(.both_edges)),
		StyleValue(GuaranteedInvalidStyleValue.create()),
		StyleValue(GridAutoFlowStyleValue.create(.column, .yes)),
	]
}

fn assert_property_export_matches(actual StyleValue, expected StyleValue) {
	// Keep failures scalar: formatting either complete owner graph is expensive.
	assert actual.equals(expected)
	assert actual.serialize(.normal) == expected.serialize(.normal)
	assert actual.serialize(.resolved_value) == expected.serialize(.resolved_value)
}

fn test_property_value_export_owns_every_supported_scalar_payload() {
	expected := StyleValue(StyleValueList.create(property_export_scalar_values(), .comma, .no))
	scratch := platform.begin_thread_scratch('test property scalar export')
	temporary := StyleValue(StyleValueList.create(property_export_scalar_values(), .comma, .no))
	assert property_value_can_export(temporary)
	scratch.leave()
	owned := export_property_value(temporary)
	scratch.finish()
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert_property_export_matches(owned, expected)
}

fn property_export_nested_value() StyleValue {
	ratio := StyleValue(RatioStyleValue.create_from_style_values(StyleValue(NumberStyleValue.create(16)),
		StyleValue(NumberStyleValue.create(9))))
	color := StyleValue(RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(0)),
		StyleValue(NumberStyleValue.create(0)), StyleValue(NumberStyleValue.create(128)),
		StyleValue(NumberStyleValue.create(1)), .legacy, 'navy'.clone()))
	list := StyleValue(StyleValueList.create([ratio, color], .space, .no))
	return StyleValue(ShorthandStyleValue.create(.margin, [.margin_top, .margin_right],
		[list, StyleValue(LengthStyleValue.create(Length.make_px(7)))]))
}

fn test_property_value_export_owns_nested_lists_ratios_shorthands_and_rgb_names() {
	expected := property_export_nested_value()
	scratch := platform.begin_thread_scratch('test nested property export')
	temporary := property_export_nested_value()
	assert property_value_can_export(temporary)
	scratch.leave()
	owned := export_property_value(temporary)
	scratch.finish()
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert_property_export_matches(owned, expected)
}

fn test_property_value_export_rejects_unsupported_descendants_before_publication() {
	mut parser := Parser.from_css_text('calc(13px + sibling-index() * 2px)')
	calculated := parser.parse_css_value(.width) or { panic('missing calculated value') }
	nested := StyleValue(ShorthandStyleValue.create(.margin, [.margin_top], [
		StyleValue(StyleValueList.create([StyleValue(NumberStyleValue.create(1)), calculated],
			.space, .yes)),
	]))
	before := platform.thread_arena_usage().used
	for _ in 0 .. 64 {
		assert !property_value_can_export(calculated)
		assert !property_value_can_export(nested)
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 1024
	}
}

fn test_property_value_workspace_preserves_supported_parser_graphs_and_serialization() {
	properties := [PropertyID.width, .opacity, .z_index, .display, .margin, .padding, .aspect_ratio,
		.background_repeat, .scrollbar_gutter, .grid_auto_flow, .color, .color, .flex, .overflow]
	sources := ['17px', '.375', '-17', 'inline flex', '1px 2em 3% 0', '1px 2px', '16 / 9',
		'repeat-x, no-repeat', 'stable both-edges', 'column dense', '#069', 'navy', '1 0 10px',
		'hidden auto']
	for i, property in properties {
		mut reference := Parser.from_css_text(sources[i])
		expected := reference.parse_css_value(property) or { panic('reference value missing') }
		assert property_value_can_export(expected)
		actual := parse_css_value_logic(property, sources[i]) or { panic('exported value missing') }
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert_property_export_matches(actual, expected)
	}
}

fn test_property_value_workspace_fallback_preserves_unsupported_graphs_and_decoded_input() {
	properties := [PropertyID.width, .content, .font_family, .background_image, .filter, .width,
		.aspect_ratio]
	sources := ['calc(13px + sibling-index() * 2px)', r'"esc\61 ped"', r'"f\61 mily", serif',
		r'image-set(url("esc\61 ped.png") 1x, url(other.png) 2x)', 'blur(2px)',
		r'var(--esc\61 ped, calc(7px + env(safe-area-inset-left, 2px)))',
		'calc(6em * sibling-index() / 1px) / calc(3rem / 1px)']
	for i, property in properties {
		mut reference := Parser.from_css_text(sources[i])
		expected := reference.parse_css_value(property) or { panic('reference fallback missing') }
		if i in [2, 5] {
			assert property_value_can_export(expected) == !disable_retained_text_value_export
		} else { assert !property_value_can_export(expected) }
		actual := parse_css_value_logic(property, sources[i]) or { panic('fallback value missing') }
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert_property_export_matches(actual, expected)
	}
}

fn test_property_value_workspace_keeps_lazy_initial_values_in_their_persistent_owner() {
	// Border fills omitted reset-only longhands from the shared initial-value
	// cache. A first parse can create those entries inside the grammar workspace.
	value := parse_css_value_logic(.border, '2px dashed navy') or {
		panic('missing border value')
	}
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert value.serialize(.normal) == '2px dashed navy'
	assert computed_interpolation_property_initial_value(.border_image_slice).css_text == '100%'
	assert computed_interpolation_property_initial_value(.border_image_source).css_text == 'none'
}

fn test_property_value_workspace_retires_failed_large_grammar_candidates() {
	// The final delimiter invalidates an otherwise large list. No candidate value
	// or grammar vector is part of the published result.
	components := parse_component_values_for_value_logic('family,'.repeat(2048) + '!')
	context := ParsingParams{}
	mut reference := Parser{ component_values: components }
	reference_succeeded := if _ := reference.parse_css_value(.font_family) { true } else { false }
	assert !reference_succeeded
	before := platform.thread_arena_usage().used
	for _ in 0 .. 8 {
		succeeded := if _ := parse_property_components_with_export(context, .font_family,
			components, false) {
			true
		} else {
			false
		}
		assert !succeeded
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 8192
	}
}
