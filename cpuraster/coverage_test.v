module cpuraster

fn test_opaque_coverage_blending_matches_both_rgba_rounding_rules() {
	white := u32(0xffffffff)
	for alpha in 0 .. 256 {
		for coverage in 0 .. 256 {
			dst := u32(alpha) << 24
			legacy_mask := blend_solid_mask_pixel(white, white, dst, u32(coverage))
			legacy_pair := fast_four_byte_interp(white, dst, u32(coverage))
			assert a8_legacy_opaque_over(u8(coverage), u8(alpha)) == u8(legacy_mask >> 24)
			assert a8_legacy_opaque_interp(u8(coverage), u8(alpha)) == u8(legacy_pair >> 24)
			assert a8_srcover(u8(coverage), u8(alpha)) == u8(lowp_lerp(u32(alpha), 255,
				u32(coverage)))
		}
	}
}

fn test_opaque_coverage_preserves_rgba_alpha_for_overlapping_clip_paths() {
	width, height := 41, 29
	mut box := PathBuilder{}
	box.move_to(-3.125, 6.5625)
	box.line_to(33.625, 6.5625)
	box.line_to(33.625, 26.3125)
	box.line_to(-3.125, 26.3125)
	box.close()

	mut compound := PathBuilder{}
	compound.move_to(1.8125, 6.5625)
	compound.quad_to(15.25, -2, 25.75, 6.5625)
	compound.cubic_to(46, 12, 28, 32, 7.25, 21.25)
	compound.line_to(1.8125, 6.5625)
	compound.close()
	compound.move_to(9.625, 7.125)
	compound.line_to(21.4375, 7.125)
	compound.line_to(21.4375, 16.5)
	compound.line_to(9.625, 16.5)
	compound.close()
	compound.fill_type = .even_odd

	mut thin := PathBuilder{}
	thin.move_to(0.25, -0.5)
	thin.line_to(1.625, -0.5)
	thin.line_to(1.625, 14.75)
	thin.line_to(0.25, 14.75)
	thin.close()

	rect, curve, strip := box.detach(), compound.detach(), thin.detach()
	identity := [f32(1), 0, 0, 1, 0, 0]!
	shift := [f32(1), 0, 0, 1, 1.1875, -1.5625]!
	paths := [curve, rect, strip, strip, curve]
	transforms := [shift, identity, shift, shift, identity]
	for legacy in [false, true] {
		mut rgba := []u8{len: width * height * 4}
		mut coverage := []u8{len: width * height}
		for i, path in paths {
			assert fill_canvas_path_surface(mut rgba, width, height, width * 4, 2, path,
				transforms[i], 0xffffffff, none, 1, .src_over, 0, [], none, legacy)
			assert fill_opaque_coverage_surface(mut coverage, width, height, path,
				transforms[i], legacy)
			expected := []u8{len: width * height, init: rgba[index * 4 + 3]}
			assert coverage == expected
		}
		assert coverage.any(it > 0 && it < 255)
		assert coverage.any(it == 255)
		assert coverage.any(it == 0)
	}
}

fn test_opaque_coverage_rejects_unsupported_devices_and_inverse_fill() {
	mut path := PathBuilder{}
	path.fill_type = .inverse_winding
	inverse := path.detach()
	matrix := [f32(1), 0, 0, 1, 0, 0]!
	mut pixels := [u8(219), 143]
	assert !fill_opaque_coverage(mut pixels, 2, 1, inverse, matrix)
	assert !fill_opaque_coverage(mut pixels, 3, 1, Path{}, matrix)
	assert !fill_opaque_coverage(mut pixels, 8192, 1, Path{}, matrix)
	assert !fill_opaque_coverage(mut pixels, -1, 1, Path{}, matrix)
	assert pixels == [u8(219), 143]
}
