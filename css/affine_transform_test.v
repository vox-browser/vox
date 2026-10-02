module css

fn test_source_affine_scale_translate_and_full_inverse_map() {
	mut transform := AffineTransform{
		scale_x:     2
		shear_y:     1
		shear_x:     3
		scale_y:     4
		translate_x: 5
		translate_y: 6
	}
	transform.translate(7, 8)
	assert transform.translate_x == 43 && transform.translate_y == 45
	transform.scale(2, 3)
	assert transform.scale_x == 4 && transform.shear_y == 2
	assert transform.shear_x == 9 && transform.scale_y == 12
	assert transform.map_int_point(1, 2) == [65, 71]!
	assert transform.inverse_map(CSSPixelPoint.from_values(65.75, 71.75)).to_double_pair() == [
		f64(1),
		2,
	]!
}

fn test_source_affine_singular_inverse_uses_identity_before_integer_mapping() {
	transform := AffineTransform{ scale_x: 0 }
	assert transform.inverse() == none
	assert transform.inverse_map(CSSPixelPoint.from_values(3.75, -4.75)).to_double_pair() == [
		f64(3),
		-4,
	]!
	assert affine_round_to_int(0.5) == 0 && affine_round_to_int(1.5) == 2
	assert affine_round_to_int(-0.5) == 0 && affine_round_to_int(-1.5) == -2
}
