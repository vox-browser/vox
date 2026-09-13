module svg

fn test_svg_length_value_factories_preserve_scalar_kind() {
	number_value := SvgLengthValue.number(12.5)
	assert number_value.kind == .number
	assert number_value.value == 12.5
	assert number_value.to_string() == '12.5'

	percentage_value := SvgLengthValue.percentage(25)
	assert percentage_value.kind == .percentage
	assert percentage_value.value == 25
	assert percentage_value.to_string() == '25%'

	length_value := SvgLengthValue.length(2.25, .ems)
	assert length_value.kind == .length
	assert length_value.unit == .ems
	assert length_value.to_string() == '2.25em'
}

fn test_svg_length_value_uses_canonical_unit_spellings() {
	assert SvgLengthValue.length(1, .exs).to_string() == '1ex'
	assert SvgLengthValue.length(1, .inches).to_string() == '1in'
	assert SvgLengthValue.length(1, .px).to_string() == '1px'
	assert SvgLengthValue.percentage(-0.0).to_string() == '0%'
}
