module cpuraster

import crypto.sha256

// The pattern tests' background, image and clip triangle.
fn image_test_background() []u8 {
	mut px := []u8{len: 48 * 40 * 4}
	for y in 0 .. 40 {
		for x in 0 .. 48 {
			o := (y * 48 + x) * 4
			a := if (x * 3 + y) % 11 == 0 { 0 } else { (x * 9 + y * 4) % 256 }
			px[o + 3] = u8(a)
			px[o] = u8(a * y / 40)
			px[o + 1] = u8(a / 2)
			px[o + 2] = u8(a * x / 48)
		}
	}
	return px
}

fn image_test_bitmap(width int, height int, premultiplied bool, display_p3 bool) CanvasBitmap {
	pitch := width * 4 + 4
	mut px := []u8{len: pitch * height}
	for y in 0 .. height {
		for x in 0 .. width {
			o := y * pitch + x * 4
			mut a := (x * 37 + y * 91) % 256
			if (x + 2 * y) % 5 == 0 {
				a = 255
			}
			if (x * 3 + y) % 7 == 3 {
				a = 0
			}
			c := [(x * 53 + y * 17) % 256, (x * 11 + y * 67) % 256, (x * 29 + y * 41 + 100) % 256]
			for i in 0 .. 3 {
				px[o + i] = u8(if premultiplied { c[i] * a / 255 } else { c[i] })
			}
			px[o + 3] = u8(a)
		}
	}
	return CanvasBitmap{
		pixels:        px
		width:         width
		height:        height
		pitch:         pitch
		premultiplied: premultiplied
		display_p3:    display_p3
	}
}

fn image_test_clips(clip bool) []Path {
	if !clip {
		return []
	}
	mut b := PathBuilder{}
	b.move_to(2, 3)
	b.line_to(45.5, 10.25)
	b.line_to(20.5, 38)
	b.close()
	return [b.detach()]
}

const image_test_identity = [f32(1), 0, 0, 1, 0, 0]!

fn clear_test_hash(transform [6]f32, destination [4]f32, color u32, clip bool) string {
	mut px := image_test_background()
	assert clear_canvas_rect(mut px, 48, 40, 192, 2, transform, destination, color, image_test_clips(clip))
	return sha256.sum(px).hex()[..16]
}

struct ImageTestCase {
	smoothing     bool
	mode          BlendMode = .src_over
	premultiplied bool      = true
	display_p3    bool
	// The canvas transform; all zeros is the identity.
	transform   [6]f32
	alpha       f32 = 1
	destination [4]f32
	source      [4]f32
	clip        bool
}

fn image_test_hash(c ImageTestCase) string {
	mut px := image_test_background()
	transform := if c.transform == [6]f32{} { image_test_identity } else { c.transform }
	source := if c.source == [4]f32{} { [f32(0), 0, 7, 6]! } else { c.source }
	assert draw_canvas_image(mut px, 48, 40, 192, 2, transform, image_test_bitmap(7, 6, c.premultiplied,
		c.display_p3), source, c.destination, c.smoothing, c.alpha, c.mode, image_test_clips(c.clip))
	return sha256.sum(px).hex()[..16]
}

fn image_filter_test_hash(c ImageTestCase, step CanvasFilterStep, bitmap_space bool) string {
	mut pixels := image_test_background()
	transform := if c.transform == [6]f32{} { image_test_identity } else { c.transform }
	source := if c.source == [4]f32{} { [f32(0), 0, 7, 6]! } else { c.source }
	assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
		image_test_bitmap(7, 6, c.premultiplied, c.display_p3), source, c.destination,
		c.smoothing, c.alpha, c.mode, image_test_clips(c.clip), new_canvas_filter([step]), bitmap_space)
	return sha256.sum(pixels).hex()[..16]
}

fn test_color_filtered_image_subsets_match_native_source_images() {
	step := image_test_contrast_filter()
	cases := [
		ImageTestCase{destination: [f32(10), 12, 7, 6]!, alpha: .7},
		ImageTestCase{premultiplied: false, display_p3: true, source: [f32(1), 1, 5, 4]!,
			destination: [f32(4), 6, 5, 4]!, alpha: .65, mode: .src_in, clip: true},
		ImageTestCase{premultiplied: false, destination: [f32(12), 10, 7, 6]!, alpha: .35,
			mode: .color_dodge, clip: true, smoothing: true},
		ImageTestCase{source: [f32(2), 1, 4, 4]!, destination: [f32(8), 10, 4, 4]!,
			mode: .plus_lighter, clip: true},
	]
	// Captured from the native image-filter entry point, which defers image
	// pixels through the alpha/filter stages until the restore blend.
	hashes := ['fcdf07f1784c94ae', 'cdff66946d64f415', '79f27b4c61142d18', 'e3441259be4b7ca6']
	for i, c in cases { assert image_filter_test_hash(c, step, false) == hashes[i] }
}

fn image_test_contrast_filter() CanvasFilterStep {
	return CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
		matrix: [f32(1.3), 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15, 0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0]!
	}}
}

fn test_nearest_filtered_images_preserve_transforms_and_aa_edges() {
	cases := [
		ImageTestCase{destination: [f32(4.25), 5.5, 30, 25]!,
			transform: [f32(1.25), 0, 0, .75, 2, 4]!, alpha: .7, clip: true},
		ImageTestCase{premultiplied: false, display_p3: true, source: [f32(1), 1, 5, 4]!,
			destination: [f32(4), 6, 35, 24]!, transform: [f32(.9), .4, -.4, .9, 5, 2]!,
			alpha: .65, mode: .multiply, clip: true},
		ImageTestCase{destination: [f32(10.01), 12.01, 7.002, 6.002]!, alpha: .35,
			mode: .color_dodge, clip: true},
		ImageTestCase{destination: [f32(5.25), 6.5, 22, 18]!,
			transform: [f32(-1.2), 0, 0, .8, 42, 3]!, alpha: .7, mode: .overlay, clip: true},
	]
	// The same four native captures on macOS and Linux.
	hashes := ['e025e6ff0e8b6e21', '116d6bd4d0f19821', '171f9638805833aa', '52406c90e7dae2ce']
	for i, c in cases { assert image_filter_test_hash(c, image_test_contrast_filter(), false) == hashes[i] }
}

fn test_linear_filtered_images_preserve_transforms_and_sampling() {
	assert image_filter_test_hash(ImageTestCase{
		destination: [f32(4.25), 5.5, 30, 25]!
		transform: [f32(1.25), 0, 0, .75, 2, 4]!
		alpha: .7
		clip: true
		smoothing: true
	}, image_test_contrast_filter(), false) == 'd5f8f3845bfa1191'
	assert image_filter_test_hash(ImageTestCase{
		premultiplied: false
		display_p3: true
		source: [f32(1), 1, 5, 4]!
		destination: [f32(4), 6, 35, 24]!
		transform: [f32(.9), .4, -.4, .9, 5, 2]!
		alpha: .65
		mode: .multiply
		clip: true
		smoothing: true
	}, image_test_contrast_filter(), false) == 'e95056f459921fcc'
	// The odd-size source subset samples levels 1 and 2. Mixing precedes
	// unpremultiplication and Display P3 conversion, as in the native shader.
	for p3 in [false, true] {
		mut pixels := image_test_background()
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2,
			if p3 { [f32(.9), .4, -.4, .9, 5, 2]! } else { image_test_identity },
			image_test_bitmap(31, 25, !p3, p3), [f32(1), 2, 28, 21]!, [f32(6.25), 5.75, 8, 7]!,
			true, .85, .multiply, image_test_clips(true), new_canvas_filter([image_test_contrast_filter()]), false)
		assert sha256.sum(pixels).hex()[..16] == if p3 { 'b7ec0bc884c06b1c' } else { '4d2545a295b0c06a' }
	}
}

fn test_bitmap_space_filtered_images_match_native_cpu_policy() {
	assert image_filter_test_hash(ImageTestCase{
		destination: [f32(4.25), 5.5, 30, 25]!
		transform: [f32(1.25), 0, 0, .75, 2, 4]!
		alpha: .7
		mode: .src_in
		clip: true
		smoothing: true
	}, CanvasFilterStep{kind: .blur, sigma: 2.5}, true) == $if linux {
		'f4d9427bb86e8fe8'
	} $else { 'b04f05f0f7807d28' }
	assert image_filter_test_hash(ImageTestCase{
		premultiplied: false
		destination: [f32(3), 8, 7, 6]!
		transform: [f32(.9), .4, -.4, .9, 5, 2]!
		alpha: .35
	}, CanvasFilterStep{kind: .drop_shadow, sigma: .8, offset_x: -7.25,
		offset_y: 4.5, color: 0x805030e0}, true) == '742faaa5a08e2c8d'
}

fn test_bitmap_space_shadow_requests_all_unbounded_source_pixels() {
	mut pixels := []u8{len: 10 * 20 * 4}
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, sigma: .85911834,
		offset_x: -8.656294, offset_y: -15, color: 0xffffffff}])
	assert draw_canvas_image_filtered(mut pixels, 10, 20, 40, 2, image_test_identity,
		image_test_bitmap(21, 22, false, false), [f32(0), 0, 21, 22]!, [f32(3), 8, 21, 22]!,
		true, .27487868, .color_dodge, [], filter, true)
	assert sha256.sum(pixels).hex()[..16] == '7a9e4b5a7ebf291f'
}

fn test_unsupported_image_filters_preserve_the_destination() {
	mut pixels := image_test_background()
	before := pixels.clone()
	filter := new_canvas_filter([CanvasFilterStep{kind: .blur, sigma: 2.5}])
	assert !draw_canvas_image_filtered(mut pixels, 48, 40, 192, 1, image_test_identity,
		image_test_bitmap(7, 6, true, false), [f32(0), 0, 7, 6]!, [f32(4), 5, 30, 25]!,
		true, 1, .src_over, [], filter, false)
	assert pixels == before
}

fn test_rgba_image_sprite_uses_the_native_filter_layer_layout() {
	mut pixels := []u8{len: 65 * 44 * 4}
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, sigma: .030803392,
		offset_x: -4, offset_y: -17.134123, color: 0x928e150c}])
	assert draw_canvas_image_filtered(mut pixels, 65, 44, 260, 2,
		[f32(1), 0, 0, 1, -8, -15]!, image_test_bitmap(2, 13, true, false),
		[f32(0), 0, 2, 3]!, [f32(49), 39, 2, 3]!, true, .43391985, .soft_light, [], filter, true)
	// RGBA source into Linux BGRA N32 uses the pipeline sprite; RGBA into
	// macOS RGBA N32 uses the legacy sprite, with different alpha rounding.
	$if linux {
		assert pixels[(25 * 65 + 41) * 4] == 3
		assert sha256.sum(pixels).hex() == 'db8e82ac8377bd19932b34383e9272bad68455ad9cc09ca08a32f4ddf9a53f31'
	} $else {
		assert pixels[(25 * 65 + 41) * 4] == 2
		assert sha256.sum(pixels).hex() == '6dd8c713245e52c2e26c67ae0ee0836ddc25e3f8113b860dcb6c47dbe046cef9'
	}
}

// Hashes of vox_skia_canvas_path()'s bitmap commands with LibWeb Skia for
// the same cases (test_cpu_raster.sh compares random ones).
fn test_clears_match_skia() {
	// A hard rect clip, then Src of transparent black.
	assert clear_test_hash(image_test_identity, [f32(3.5), 4.25, 30, 20]!, 0, false) == fixture_hash('4862b730d1fb2247')
	// Opaque black (alpha: false) is source-over, under a flipping scale.
	assert clear_test_hash([f32(1.5), 0, 0, -1.2, 2, 39]!, [f32(2), 3, 20, 15]!, 0xff000000,
		false) == fixture_hash('438681b38b121c8c')
	// Inside an anti-aliased clip.
	assert clear_test_hash(image_test_identity, [f32(0), 0, 48, 40]!, 0, true) == fixture_hash('62b1b888837ad40a')
}

fn test_sprite_images_match_skia() {
	// Unscaled premultiplied images: Sprite_D32_S32, the Memcpy sprite for
	// copy and blit_row_s32a_blend at half alpha.
	assert image_test_hash(ImageTestCase{
		destination: [f32(10), 12, 7, 6]!
	}) == fixture_hash('eba880bbda5f6f4a')
	assert image_test_hash(ImageTestCase{
		mode:        .src
		destination: [f32(10), 12, 7, 6]!
	}) == fixture_hash('96f513ac0f45d7a2')
	assert image_test_hash(ImageTestCase{
		alpha:       0.5
		destination: [f32(10), 12, 7, 6]!
	}) == fixture_hash('0495a4388ca940c9')
	// Display P3: SkRasterPipelineSpriteBlitter.
	assert image_test_hash(ImageTestCase{
		display_p3:  true
		destination: [f32(10), 12, 7, 6]!
	}) == fixture_hash('d4051cafcbbe1366')
	// An anti-aliased clip that cuts the sprite takes the shader instead.
	assert image_test_hash(ImageTestCase{
		destination: [f32(30), 14, 7, 6]!
		clip:        true
	}) == fixture_hash('7a1823380c32d1fe')
}

fn test_scaled_images_match_skia() {
	// Nearest and bilinear legacy contexts, a bilinear subset away from the
	// origin, and a source rect past the image.
	assert image_test_hash(ImageTestCase{
		destination: [f32(5), 5, 20, 14]!
	}) == fixture_hash('3e8084e20b39a7f3')
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		destination: [f32(5), 5, 20, 14]!
	}) == fixture_hash('9c725c14254b2f62')
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		destination: [f32(6), 4, 30, 20]!
		source:      [f32(2), 1, 4, 3]!
	}) == fixture_hash('24d847ccb95ac95d')
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		destination: [f32(4), 3, 30, 25]!
		source:      [f32(-2), -1, 6, 5]!
	}) == fixture_hash('48cbeda9149b9d90')
	// Unpremultiplied: the raster pipeline's lowp bilerp_clamp_8888.
	assert image_test_hash(ImageTestCase{
		smoothing:     true
		premultiplied: false
		destination:   [f32(5.5), 5, 21, 14]!
	}) == fixture_hash('090261b8b1015058')
	// A quarter turn keeps rects rects: the nearest affine legacy procs.
	assert image_test_hash(ImageTestCase{
		transform:   [f32(0), 1, -1, 0, 44, 2]!
		destination: [f32(5), 5, 20, 14]!
	}) == fixture_hash('d256feaf2557e392')
	// Multiply at partial alpha through the pipeline.
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		mode:        .multiply
		alpha:       0.8
		destination: [f32(5), 5, 20, 14]!
	}) == fixture_hash('756d48e5937f902d')
}

// Under a rotation both commands fill the rect's path without
// anti-aliasing: SkScan::FillPath() into a region for the clear's clip
// (intersected with an anti-aliased clip through SkAAClip::setRegion()),
// and through the image shader for drawImage().
fn test_rotated_commands_match_skia() {
	rotation := [f32(0.9), 0.4, -0.4, 0.9, 5, 2]!
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		transform:   rotation
		destination: [f32(5), 5, 20, 14]!
	}) == fixture_hash('e05cc38cab516e92')
	assert image_test_hash(ImageTestCase{
		mode:          .multiply
		premultiplied: false
		transform:     rotation
		alpha:         0.7
		destination:   [f32(5), 5, 20, 14]!
		source:        [f32(1), 1, 5, 4]!
		clip:          true
	}) == fixture_hash('cf98fb1fb46fb2ee')
	assert clear_test_hash(rotation, [f32(6), 5, 25, 18]!, 0, false) == fixture_hash('38711e4839a270f0')
	assert clear_test_hash(rotation, [f32(6), 5, 25, 18]!, 0xff000000, true) == fixture_hash('4524d50a45b3d820')
}
