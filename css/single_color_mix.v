module css

fn single_color_mix_value(method ?ColorInterpolationMethodStyleValue, component ColorMixComponent) ?StyleValue {
	mut percentage := ?StyleValue(none)
	if weight := component.percentage {
		if weight is PercentageStyleValue {
			if weight.percentage().value() == 0 { return none }
			percentage = StyleValue(PercentageStyleValue.create(Percentage.new(weight.percentage().value()/2)))
		} else {
			// Keep calculation evaluation in the normal computation context.
			percentage = parse_css_value_logic(.opacity, 'calc(${weight.serialize(.normal)} / 2)')
		}
	}
	entry := ColorMixComponent{color:component.color,percentage:percentage}
	return StyleValue(ColorMixStyleValue{...ColorMixStyleValue.create(method,entry,entry),single_component:[component]})
}
