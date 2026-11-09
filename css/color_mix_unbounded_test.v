module css

fn test_converted_color_mix_coordinates_preserve_negative_lightness() {
	for source in ['color-mix(in lch, oklch(0 0.2 0))','color-mix(in oklch, lch(0 20 180))'] {
		value := parse_css_value_logic(.color,source) or { panic(source) }
		computed := value.absolutized(ComputationContext{})
		serialized := computed.serialize(.resolved_value)
		assert serialized.contains('ch(-'),serialized
		assert computed.absolutized(ComputationContext{}).serialize(.resolved_value) == serialized
	}
	value := parse_css_value_logic(.color,'lch(-20 10 20)') or { panic('absolute') }
	assert value.absolutized(ComputationContext{}).serialize(.resolved_value) == 'lch(0 10 20)'
}
