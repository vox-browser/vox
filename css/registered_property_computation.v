module css

import dom

fn computed_registered_initial_value(owner dom.AbstractElement, name string) ?&dom.StyleValue {
	initial := owner.document().custom_property_initial_value(name) or { return none }
	properties := up_to_date_computed_properties_for_element(owner.element())
	computer := css_style_computer_for(owner.document())
	return computer.compute_animated_custom_property_value(owner, properties, name, parse_custom_property_value(initial))
}

// Registered colors compute currentcolor against the element's completed
// color before their typed result is inherited by another element.
fn compute_registered_typed_value(value StyleValue, context ComputationContext, colors ColorResolutionContext) StyleValue {
	if value is StyleValueList {
		mut values := []StyleValue{}
		for item in value.values() { values << compute_registered_typed_value(item, context, colors) }
		return StyleValue(StyleValueList.create(values, value.separator(), value.collapsible_))
	}
	if value is KeywordStyleValue && value.keyword() == .currentcolor {
		return StyleValue(ColorStyleValue.create_from_color(colors.current_color or { Color.black() }, .legacy, none))
	}
	if value is LightDarkStyleValue && !value.image_ {
		dark := if scheme := colors.color_scheme { scheme == .dark } else { false }
		branch := if dark { value.dark[0] } else { value.light[0] }
		return compute_registered_typed_value(branch, context, colors)
	}
	if value is ColorMixStyleValue {
		first := value.first_component[0]
		second := value.second_component[0]
		return StyleValue(ColorMixStyleValue.create(value.color_interpolation_method,
			ColorMixComponent{color:compute_registered_typed_value(first.color, context, colors),percentage:first.percentage},
			ColorMixComponent{color:compute_registered_typed_value(second.color, context, colors),percentage:second.percentage})).absolutized(context)
	}
	if is_relative_color(value) { return resolve_relative_color_for_use(value, colors).absolutized(context) }
	if value is ColorFunctionStyleValue {
		return StyleValue(ColorFunctionStyleValue.create(color_space_from_color_type(value.color_type_),
			compute_registered_typed_value(value.channels_[0], context, colors),
			compute_registered_typed_value(value.channels_[1], context, colors),
			compute_registered_typed_value(value.channels_[2], context, colors),
			compute_registered_typed_value(value.alpha_.value, context, colors)))
	}
	computed := value.absolutized(context)
	if computed is CalculatedStyleValue {
		return computed.resolve_as_style_value(CalculationResolutionContext.from_computation_context(context, none)) or { computed }
	}
	if computed is AngleStyleValue { return StyleValue(AngleStyleValue.create(Angle.make_degrees(computed.angle().to_degrees()))) }
	if computed is TimeStyleValue { return StyleValue(TimeStyleValue.create(Time.make_seconds(computed.time().to_seconds()))) }
	if computed is ResolutionStyleValue { return StyleValue(ResolutionStyleValue.create(Resolution.make_dots_per_pixel(computed.resolution().to_dots_per_pixel()))) }
	if computed is FrequencyStyleValue { return StyleValue(FrequencyStyleValue.create(Frequency.make_hertz(computed.frequency().to_hertz()))) }
	return computed
}
