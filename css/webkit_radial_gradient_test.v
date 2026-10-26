module css

fn webkit_radial_test_value(text string, property PropertyID) ?RadialGradientStyleValue {
	value := parse_css_value_logic(property, text) or { return none }
	image := if list := value.as_value_list() { list.value_at(0, false) } else { value }
	return image.as_radial_gradient()
}

fn test_webkit_radial_gradient_accepts_pikabu_mask_and_keeps_legacy_serialization() {
	for property in [PropertyID.mask_image, .background_image] {
		gradient := webkit_radial_test_value('-webkit-radial-gradient(circle, #fff 100%, #000 100%)', property)?
		assert gradient.webkit_
		assert gradient.ending_shape_ == .circle
		assert gradient.color_stop_list_.len == 2
		assert gradient.position_.is_center(.normal)
		assert gradient.serialize(.normal) == '-webkit-radial-gradient(center, circle cover, rgb(255, 255, 255) 100%, rgb(0, 0, 0) 100%)'
		computed := gradient.absolutized(ComputationContext{}) as RadialGradientStyleValue
		assert computed.serialize(.normal) == gradient.serialize(.normal)
	}
}

fn test_webkit_radial_gradient_positions_extents_and_radii_survive_round_trip() {
	for text in [
		'-webkit-radial-gradient(red, blue)',
		'-webkit-radial-gradient(left top, circle contain, red, blue)',
		'-webkit-radial-gradient(25% 75%, cover ellipse, red 10px 20px, blue)',
		'-webkit-radial-gradient(center, 20px 40%, red, blue)',
		'-webkit-radial-gradient(center, calc(10px + 5%) 40%, red, blue)',
		'-webkit-repeating-radial-gradient(center, closest-side circle, red 0%, blue 25%)',
		'-webkit-radial-gradient(circle red, blue)',
		'-webkit-radial-gradient(red)',
		'-webkit-radial-gradient(red 0% 100%)',
	] {
		first := webkit_radial_test_value(text, .background_image)?
		second := webkit_radial_test_value(first.serialize(.normal), .background_image)?
		assert first.serialize(.normal) == second.serialize(.normal)
		assert first.ending_shape_ == second.ending_shape_
		assert first.size_.serialize(.normal) == second.size_.serialize(.normal)
		assert first.is_repeating() == text.contains('repeating')
	}
	contain := webkit_radial_test_value('-webkit-radial-gradient(contain, red, blue)', .background_image)?
	assert contain.size_.serialize(.normal) == 'closest-side'
	cover := webkit_radial_test_value('-webkit-radial-gradient(cover, red, blue)', .background_image)?
	assert cover.size_.serialize(.normal) == 'farthest-corner'
	uppercase := webkit_radial_test_value('-WEBKIT-REPEATING-RADIAL-GRADIENT(circle, red, blue)', .background_image)?
	assert uppercase.webkit_
	assert uppercase.is_repeating()
}

fn test_webkit_radial_gradient_rejects_standard_only_and_malformed_grammar() {
	for text in [
		'-webkit-radial-gradient(at center, red, blue)',
		'-webkit-radial-gradient(circle at center, red, blue)',
		'-webkit-radial-gradient(left 10px top 20px, red, blue)',
		'-webkit-radial-gradient(center red, blue)',
		'-webkit-radial-gradient(center, 20px, red, blue)',
		'-webkit-radial-gradient(center, -10px 20px, red, blue)',
		'-webkit-radial-gradient(center, 10px -20%, red, blue)',
		'-webkit-radial-gradient(circle circle, red, blue)',
		'-webkit-radial-gradient(contain cover, red, blue)',
		'-webkit-radial-gradient(red, 50%, blue)',
		'-webkit-radial-gradient(10% red, blue)',
		'-webkit-radial-gradient(red 0% 25% 50%, blue)',
		'-webkit-radial-gradient(in srgb, red, blue)',
		'-webkit-radial-gradient(red, blue,)',
	] {
		assert webkit_radial_test_value(text, .background_image) == none
	}
}
