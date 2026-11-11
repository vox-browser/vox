module cpuraster

import platform

fn shadow_test_alpha(pixels []u8, width int, x int, y int) u8 {
	return pixels[(y * width + x) * 4 + 3]
}

fn test_outer_shadow_blurs_elliptical_corners_and_excludes_content() {
	shape := ShadowRect{ rect: [f32(8), 8, 16, 16]!, radii: [f32(6), 4, 2, 6, 4, 2, 2, 2]! }
	pixels := rasterize_shadow(32, 32, ShadowCommand{
		kind: 0
		color: 0xff0000ff
		blur: 4
		transform: [f32(1), 0, 0, 1, 0, 0]!
		content: shape
		outer: shape
	})!
	assert shadow_test_alpha(pixels, 32, 16, 16) == 0
	assert shadow_test_alpha(pixels, 32, 5, 16) > 0
	assert shadow_test_alpha(pixels, 32, 5, 16) < 255
	assert shadow_test_alpha(pixels, 32, 0, 16) == 0
}

fn test_inner_shadow_uses_difference_path_and_rounded_content_clip() {
	shape := ShadowRect{ rect: [f32(4), 4, 24, 24]!, radii: [f32(8), 8, 8, 8, 8, 8, 8, 8]! }
	pixels := rasterize_shadow(32, 32, ShadowCommand{
		kind: 1
		color: 0xff0000ff
		blur: 4
		transform: [f32(1), 0, 0, 1, 0, 0]!
		content: shape
		outer: ShadowRect{ rect: [f32(0), 0, 32, 32]! }
		inner: ShadowRect{ rect: [f32(8), 8, 16, 16]!, radii: [f32(4), 4, 4, 4, 4, 4, 4, 4]! }
	})!
	assert shadow_test_alpha(pixels, 32, 4, 4) == 0
	assert shadow_test_alpha(pixels, 32, 6, 16) > 180
	assert shadow_test_alpha(pixels, 32, 10, 16) > 0
	assert shadow_test_alpha(pixels, 32, 10, 16) < shadow_test_alpha(pixels, 32, 6, 16)
	assert shadow_test_alpha(pixels, 32, 16, 16) == 0
}

fn test_text_shadow_uses_retained_glyph_positions_flat_tint_and_single_alpha() {
	font := &platform.Font{ family: 'sans-serif', point_size: 24 }
	run := platform.shape_text(0, 0, 'O', font, .ltr)
	positions := run.glyph_positions().map(f32(it))
	command := ShadowCommand{
		kind: 2
		color: 0x800000ff
		blur: 4
		transform: [f32(1), 0, 0, 1, 0, 0]!
		font_path: font.font_path() or { panic('font') }
		face_index: font.face_index()
		font_size: font.point_size
		glyphs: run.glyph_indices()
		positions: positions
		translation: [f32(8), 30]!
	}
	pixels := rasterize_shadow(48, 48, command)!
	mut painted := 0
	mut translucent := 0
	for index := 0; index < pixels.len; index += 4 {
		if pixels[index + 3] == 0 { continue }
		painted++
		assert pixels[index] == 0
		assert pixels[index + 1] == 0
		assert pixels[index + 2] == 255
		assert pixels[index + 3] <= 128
		if pixels[index + 3] < 128 { translucent++ }
	}
	assert painted > 100
	assert translucent > 100
}

fn test_shadow_retains_visual_context_path_clip_before_command_transform() {
	// A triangular clip has a diagonal boundary which a scissor rectangle
	// cannot reproduce. The outer shadow rectangle reaches both sides.
	segments := [
		f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	]
	pixels := rasterize_shadow(32, 32, ShadowCommand{
		kind: 0
		color: 0xff0000ff
		transform: [f32(1), 0, 0, 1, 0, 0]!
		outer: ShadowRect{ rect: [f32(0), 0, 32, 32]! }
		clips: [ShadowClip{ is_path: true, path: PackedPath{ segments: segments }, transform: [f32(1), 0, 0, 1, 0, 0]! }]
	})!
	assert shadow_test_alpha(pixels, 32, 4, 4) == 255
	assert shadow_test_alpha(pixels, 32, 28, 28) == 0
}
