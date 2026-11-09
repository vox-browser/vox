module css

fn test_conic_gradient_omits_default_zero_angle() {
	value := parse_css_value_logic(.background_image, 'conic-gradient(from 0deg, red, blue)') or { panic('gradient') }
	assert value.serialize(.normal) == 'conic-gradient(red, blue)'
}

// Validates parsing + serialization of radial/conic gradient prefixes
// (`[<shape> || <size>]? [at <position>]?` for radial, `[from <angle>]? [at
// <position>]?` for conic) and that the serialized css_text re-parses to the
// same text (round-trip stability).
//
// The port stores the radial ending shape separately from the size (upstream
// folds it into RadialSize), so `circle` is emitted by the serializer while
// `ellipse` (the default) and `farthest-corner` (the default size) are omitted.

fn gradient(text string) ?string {
	value := parse_css_value(ParsingParams{}, text, PropertyID.background_image) or { return none }
	return value.css_text
}

fn gradient_roundtrips(text string) bool {
	first := gradient(text) or { return false }
	second := gradient(first) or { return false }
	return first == second
}

fn test_radial_default_size_omits_shape_and_size() {
	// The default ellipse/farthest-corner is not serialized.
	assert gradient('radial-gradient(red, blue)')? == 'radial-gradient(red, blue)'
	assert gradient('radial-gradient(ellipse, red, blue)')? == 'radial-gradient(red, blue)'
	assert gradient('radial-gradient(farthest-corner, red, blue)')? == 'radial-gradient(red, blue)'
}

fn test_radial_circle_shape_preserved() {
	// `circle` differs from the default and must survive serialization.
	assert gradient('radial-gradient(circle, red, blue)')? == 'radial-gradient(red, blue)'
	// A default `at center` position is dropped, but the shape stays.
	assert gradient('radial-gradient(circle at center, red, blue)')? == 'radial-gradient(red, blue)'
}

fn test_radial_explicit_size_and_position() {
	assert gradient('radial-gradient(circle closest-side at 10% 20%, red, blue)')? == 'radial-gradient(closest-side at 10% 20%, red, blue)'
	assert gradient('radial-gradient(ellipse farthest-side at top left, red, blue)')?.contains('farthest-side')
}

fn test_conic_from_and_at_prefixes() {
	assert gradient('conic-gradient(from 45deg, red, blue)')? == 'conic-gradient(from 45deg, red, blue)'
	assert gradient('conic-gradient(from 90deg at 25% 25%, red, blue)')? == 'conic-gradient(from 90deg at 25% 25%, red, blue)'
	// A default `at center` is dropped.
	assert gradient('conic-gradient(at center, red, blue)')? == 'conic-gradient(red, blue)'
}

fn test_gradient_prefix_round_trips() {
	assert gradient_roundtrips('radial-gradient(red, blue)')
	assert gradient_roundtrips('radial-gradient(circle, red, blue)')
	assert gradient_roundtrips('radial-gradient(circle at center, red, blue)')
	assert gradient_roundtrips('radial-gradient(circle closest-side at 10% 20%, red, blue)')
	assert gradient_roundtrips('radial-gradient(ellipse, red, blue)')
	assert gradient_roundtrips('conic-gradient(from 45deg, red, blue)')
	assert gradient_roundtrips('conic-gradient(from 90deg at 25% 25%, red, blue)')
}
