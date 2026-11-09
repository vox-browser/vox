module css

fn test_contain_intrinsic_lengths_clamp_negative_extrapolation() {
	for property in [PropertyID.contain_intrinsic_width, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_block_size] {
		for prefix in ['', 'auto '] {
			a := parse_css_value_logic(property, '${prefix}10px') or { panic('from') }
			b := parse_css_value_logic(property, '${prefix}20px') or { panic('to') }
			value := interpolate_style_value(InterpolationCalculationContext.for_property(property), a, b, -2, .no) or { panic('interpolation') }
			assert value.serialize(.normal) == '${prefix}0px'
		}
	}
}
