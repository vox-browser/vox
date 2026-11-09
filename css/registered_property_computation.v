module css

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
	return value.absolutized(context)
}
