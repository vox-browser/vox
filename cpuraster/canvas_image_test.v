module cpuraster

import crypto.sha256
import json2

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

fn test_filtered_image_restores_cover_the_clip_with_clearing_blenders() {
	modes := [BlendMode.src, .src_in, .src_out, .dst_in, .dst_atop, .plus_darker, .plus_lighter]
	hashes := [
		['46fcd61c577e37c9', '8df3a99256c17efc', 'ee3b65cf28b7c260', '52bef994eb1f0a52',
		 '74c6cb30d370371a', '1e7ab89a4da1e16f', '5e28aece98e44f83'],
		['6a3d3514d69c10b6', '06b178d6241aeedf', '84bb844bc9446aa4', '10b411f2added94d',
		 '9dcb80513fcef5b6', '4137bfce1d4c56ef', '424a58d921b95596'],
	]
	for j, smoothing in [false, true] {
		for i, mode in modes {
			assert image_filter_test_hash(ImageTestCase{
				premultiplied: false
				display_p3: true
				source: [f32(1), 1, 5, 4]!
				destination: [f32(3.25), 4.5, 24, 18]!
				transform: if smoothing { [f32(1.25), 0, 0, .75, 2, 4]! }
					else { [f32(.9), .4, -.4, .9, 5, 2]! }
				alpha: .65
				mode: mode
				clip: true
				smoothing: smoothing
			}, image_test_contrast_filter(), false) == hashes[j][i]
		}
	}
	assert image_filter_test_hash(ImageTestCase{
		destination: [f32(3.25), 4.5, 7, 6]!
		transform: [f32(.9), 0, 0, 1.1, 2, 4]!
		alpha: .65
		mode: .src_in
		clip: true
		smoothing: true
	}, image_test_contrast_filter(), false) == 'e9ae408499d06d09'
	// A runtime decal shader invalidates the child's total-matrix record,
	// which keeps the base mip level even when the image shrinks.
	mut pixels := image_test_background()
	assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, image_test_identity,
		image_test_bitmap(11, 1, false, false), [f32(0), 0, 11, 1]!,
		[f32(2.3826473), 7.3846455, 4.1874094, 10.494535]!, true, .999, .plus_lighter, [],
		new_canvas_filter([image_test_contrast_filter()]), false)
	assert sha256.sum(pixels).hex()[..16] == 'b597b38558cfdfc1'
}

fn test_filtered_image_sources_clip_before_transforming() {
	assert image_filter_test_hash(ImageTestCase{
		source: [f32(-2), 1, 12, 9]!
		destination: [f32(3.25), 4.5, 24, 18]!
		transform: [f32(.9), .4, -.4, .9, 5, 2]!
		alpha: .65
		mode: .multiply
		clip: true
	}, image_test_contrast_filter(), false) == 'c6cdff1bcb881136'
	assert image_filter_test_hash(ImageTestCase{
		premultiplied: false
		display_p3: true
		source: [f32(-2), 1, 12, 9]!
		destination: [f32(3.25), 4.5, 24, 18]!
		transform: [f32(1.25), 0, 0, .75, 2, 4]!
		alpha: .65
		mode: .src_in
		clip: true
		smoothing: true
	}, image_test_contrast_filter(), false) == '7b33de5d39e16a66'
	for i, c in [
		ImageTestCase{source: [f32(10), 1, 5, 4]!, destination: [f32(3.25), 4.5, 24, 18]!,
			alpha: .65, mode: .src_in, clip: true},
		ImageTestCase{source: [f32(10), 1, 5, 4]!, destination: [f32(60), 50, 24, 18]!,
			alpha: .65, mode: .src_in, clip: true},
		ImageTestCase{source: [f32(-2), 1, -5, 4]!, destination: [f32(3.25), 4.5, 24, 18]!,
			alpha: .65, mode: .src_in, clip: true},
	] {
		assert image_filter_test_hash(c, image_test_contrast_filter(), false) ==
			if i == 0 { fixture_hash('62b1b888837ad40a') } else { 'f00be8e39ec6bc7f' }
	}
}

fn test_linear_filtered_image_restores_preserve_rotated_layer_edges() {
	modes := [BlendMode.src, .src_in, .src_out, .dst_in, .dst_atop, .plus_darker, .plus_lighter]
	hashes := ['a9973dbbb81b55a3', 'b9ed9372ad2fa689', '4b7094d961364ddc',
		'c014e794ae2d0531', '820e54abd9a5bdb9', '65bee32ef9751dba', '2f6d605edd08a4c8']
	for i, mode in modes {
		assert image_filter_test_hash(ImageTestCase{
			premultiplied: false
			display_p3: true
			source: [f32(1), 1, 5, 4]!
			destination: [f32(3.25), 4.5, 24, 18]!
			transform: [f32(.9), .4, -.4, .9, 5, 2]!
			alpha: .65
			mode: mode
			clip: true
			smoothing: true
		}, image_test_contrast_filter(), false) == hashes[i]
	}
	assert image_filter_test_hash(ImageTestCase{
		premultiplied: false
		display_p3: true
		source: [f32(1), 1, 5, 4]!
		destination: [f32(3.25), 4.5, 24, 18]!
		transform: [f32(.7), .45, .3, 1.2, 5, 2]!
		alpha: .65
		mode: .plus_lighter
		clip: true
		smoothing: true
	}, image_test_contrast_filter(), false) == 'f3f022c3c8bcb02f'
	// With near-unit singular values the native shader uses image-space
	// decal sampling rather than the decomposed layer-space ramp.
	assert image_filter_test_hash(ImageTestCase{
		source: [f32(1), 1, 5, 4]!
		destination: [f32(3.25), 4.5, 5, 4]!
		transform: [f32(.96), .28, -.28, .96, 5, 2]!
		alpha: .65
		mode: .src_in
		clip: true
		smoothing: true
	}, image_test_contrast_filter(), false) == '33a4cc97cfdb1da1'
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

fn test_bitmap_space_color_filters_quantize_the_source_before_restoring() {
	assert image_filter_test_hash(ImageTestCase{
		destination: [f32(10), 12, 7, 6]!
		alpha: .7
	}, image_test_contrast_filter(), true) == $if linux { '7a582a0ca4741ede' }
		$else { '26a3b278f9abcba9' }
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
	}, image_test_contrast_filter(), true) == '64abfa4e28e7d1c5'
	mut pixels := image_test_background()
	assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, image_test_identity,
		image_test_bitmap(31, 25, true, false), [f32(1), 2, 28, 21]!, [f32(6.25), 5.75, 8, 7]!,
		true, .85, .src_in, image_test_clips(true), new_canvas_filter([image_test_contrast_filter()]), true)
	assert sha256.sum(pixels).hex()[..16] == $if linux { '6d9974a54e33f8bb' }
		$else { 'b5c557eb9dd295df' }
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
	assert !draw_canvas_image_filtered(mut pixels, 48, 40, 192, 1, [f32(1), .2, 0, 1, 0, 0]!,
		image_test_bitmap(7, 6, true, false), [f32(0), 0, 7, 6]!, [f32(4), 5, 30, 25]!,
		true, 1, .src_over, [], filter, false)
	assert pixels == before
}

fn test_pixel_aligned_source_image_filter_layers_match_native() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	box := CanvasFilterStep{kind: .blur, sigma: 2.5}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	sequences := [
		[box], [gaussian],
		[CanvasFilterStep{kind: .drop_shadow, sigma: 2.5, offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}],
		[contrast, CanvasFilterStep{kind: .drop_shadow, sigma: .01, offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}, opacity],
		[contrast, gaussian, opacity, box, contrast],
		[contrast, CanvasFilterStep{kind: .blur}, opacity, CanvasFilterStep{kind: .blur, sigma: .01}, contrast],
		[box, opacity, CanvasFilterStep{kind: .blur, sigma: 12}, contrast],
	]
	hashes := ['ed3ad78eb7f39e69', '175b0777ebb477e0', '008e86865ffcec77',
		'6454322bbabaebc8', 'eb747c828384c545', '911409983b836492', '718eb0464fd3d842']
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := if i == 1 { [f32(1), 1, 5, 4]! } else { [f32(0), 0, 7, 6]! }
		destination := if i == 1 { [f32(4), 6, 5, 4]! } else { [f32(10), 12, 7, 6]! }
		transform := if i == 1 { [f32(1), 0, 0, 1, 3, -2]! } else { image_test_identity }
		mode := match i { 1, 5 { BlendMode.src_in } 2 { .multiply } 3 { .plus_lighter }
			4 { .overlay } 6 { .plus_darker } else { .src_over } }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, true, false), source, destination, true, 1, mode,
			image_test_clips(i in [1, 2, 3, 5, 6]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'aligned image layer ${i}'
	}
}

fn test_identity_shadow_preserves_unknown_source_image_boundary() {
	image := CanvasBitmap{width: 10, height: 1, pitch: 40, premultiplied: true,
		pixels: [u8(34), 60, 16, 61, 7, 85, 139, 213, 113, 115, 31, 118, 7, 2, 11, 34,
			158, 206, 247, 247, 5, 79, 27, 87, 158, 135, 41, 159, 30, 6, 46, 46,
			24, 6, 48, 64, 200, 141, 230, 254]}
	mut pixels := []u8{len: 86 * 65 * 4}
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, sigma: -1,
		offset_x: 15.59166, offset_y: 6, color: 4280761295}])
	assert draw_canvas_image_filtered(mut pixels, 86, 65, 344, 2,
		[f32(1), 0, 0, 1, 9, -6]!, image, [f32(4), 0, 6, 1]!, [f32(52), 2, 6, 1]!,
		true, 1, .src_over, [], filter, false)
	assert pixels[(2 * 86 + 82) * 4 + 2] == 121
	assert sha256.sum(pixels).hex()[..16] == 'c109c5a5d05dfb86'
}

fn test_source_image_alpha_type_and_color_space_remain_deferred() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	zero := CanvasFilterStep{kind: .blur}
	tiny := CanvasFilterStep{kind: .blur, sigma: .01}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	box := CanvasFilterStep{kind: .blur, sigma: 2.5}
	shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
		offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
	sequences := [[box], [gaussian], [gaussian, contrast, box], [tiny, box, contrast],
		[box], [box, contrast, zero], [contrast, shadow],
		[opacity, CanvasFilterStep{...shadow, sigma: .01}, contrast], [contrast, shadow],
		[contrast, zero, opacity, tiny, contrast]]
	hashes := ['b6afd442846f1fe7', 'e9153669efc21a36', 'ec04ff3914c40623', 'fbe1dc130b1bbe80',
		'b584f633e3fc82cf', 'a902cd538e64aca3', 'c62cadba69cd7310', '7f699b125a13e896',
		'a1a9893f167e696e', '001b2763877bb22c']
	for i, steps in sequences {
		mut pixels := image_test_background()
		premul := i in [0, 2, 6, 9]
		p3 := i !in [4, 5, 8]
		mode := match i { 1, 8 { BlendMode.multiply } 2, 5, 7 { .src_in }
			3 { .plus_lighter } 9 { .darken } else { .src_over } }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, image_test_identity,
			image_test_bitmap(7, 6, premul, p3), [f32(0), 0, 7, 6]!, [f32(10), 12, 7, 6]!,
			true, 1, mode, image_test_clips(i in [1, 3, 5, 7, 8, 9]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'source color info fixture ${i}'
	}
}

fn test_image_shadow_offsets_keep_the_original_layer_origin() {
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, sigma: 3.3989284,
		offset_x: 19, offset_y: 11.136544, color: 4287222027}])
	for p3 in [true, false] {
		mut pixels := []u8{len: 50 * 73 * 4}
		image := CanvasBitmap{width: 19, height: 14, pitch: 84, premultiplied: true,
			display_p3: p3, pixels: $embed_file('testdata/image-shadow-offset.rgba').to_bytes()}
		assert draw_canvas_image_filtered(mut pixels, 50, 73, 200, 2,
			[f32(1), 0, 0, 1, 9, -9]!, image, [f32(1), 2, 15, 9]!, [f32(15), -3, 15, 9]!,
			false, 1, .src_over, [], filter, false)
		assert sha256.sum(pixels).hex()[..16] == 'f2a7f0ed22c87bab'
	}
}

fn test_fractional_source_image_filters_rasterize_before_filtering() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	box := CanvasFilterStep{kind: .blur, sigma: 2.5}
	shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
		offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
	sequences := [[CanvasFilterStep{kind: .blur, sigma: 1.2}], [contrast, gaussian, opacity, box],
		[shadow], [CanvasFilterStep{...shadow, sigma: .01, offset_x: -.75, offset_y: .5}],
		[gaussian, contrast, box], [contrast, opacity]]
	hashes := $if linux {
		['068ae7ede00bb8bd', '1edd441e708f831d', 'd8e5098c0b88d10e',
		 '007ae7e038db824f', '67db8f58ce335193', '7e93e71b503d462d']
	} $else {
		['6285cc5ff30cb0e8', '1edd441e708f831d', 'd8e5098c0b88d10e',
		 '5adddb55e2daa5f2', '87142d4b2b61a427', '7e93e71b503d462d']
	}
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := if i in [0, 3] { [f32(.25), .5, 6.25, 5]! } else { [f32(1.25), 1.5, 4.5, 3.75]! }
		destination := if i in [0, 3] { [f32(10.25), 12.5, 28, 18]! } else { [f32(4.5), 6.25, 22, 16]! }
		transform := if i == 0 { [f32(1.25), 0, 0, .75, 2, 4]! }
			else if i == 4 { [f32(-1.1), 0, 0, .8, 42, 3]! } else { image_test_identity }
		mode := match i { 1 { BlendMode.overlay } 2 { .multiply } 3 { .plus_lighter } else { .src_in } }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [1, 2, 5], i in [1, 5]), source, destination,
			true, 1, mode, image_test_clips(i in [0, 2, 3, 5]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'fractional image fixture ${i}'
	}
}

fn test_source_image_paint_alpha_precedes_deferred_canvas_filters() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	zero := CanvasFilterStep{kind: .blur}
	tiny := CanvasFilterStep{kind: .blur, sigma: .01}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	box := CanvasFilterStep{kind: .blur, sigma: 2.5}
	shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
		offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
	sequences := [[box], [gaussian], [contrast, shadow],
		[opacity, CanvasFilterStep{...shadow, sigma: .01}, contrast],
		[contrast, CanvasFilterStep{...shadow, sigma: -1}],
		[contrast, gaussian, opacity, box, contrast], [contrast, zero, opacity, tiny, contrast],
		[gaussian], [CanvasFilterStep{kind: .blur, sigma: 1.2}], [contrast, opacity]]
	alphas := [f32(.7), .35, .65, .999, .43391985, .5, .65, 0, .65, .7]
	hashes := ['d97a0d9cd1df7e4d', '5e4ace20b1be0022', '0adcdf1ab86d62a6', '75e9b0d52e0b770b',
		'a13ffe5203eeb91e', '1c07622980ca4093', '502f0b408e262557', '62b1b888837ad40a',
		'7947909c7171a8d1', 'e31ad4c4058362b9']
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := if i == 8 { [f32(.25), .5, 6.25, 5]! }
			else if i == 9 { [f32(1.25), 1.5, 4.5, 3.75]! } else { [f32(0), 0, 7, 6]! }
		destination := if i == 8 { [f32(10.25), 12.5, 28, 18]! }
			else if i == 9 { [f32(4.5), 6.25, 22, 16]! } else { [f32(10), 12, 7, 6]! }
		transform := if i == 8 { [f32(1.25), 0, 0, .75, 2, 4]! } else { image_test_identity }
		mode := match i { 0, 5 { BlendMode.src_over } 1 { .multiply }
			3 { .plus_lighter } 4 { .screen } else { .src_in } }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [1, 3, 4, 5, 9], i in [2, 5, 6, 8, 9]), source, destination,
			true, alphas[i], mode, image_test_clips(i in [1, 3, 6, 7, 8, 9]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'image paint alpha fixture ${i}'
	}
}

fn test_integer_source_images_resolve_sampling_and_color_before_blur() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	box := CanvasFilterStep{kind: .blur, sigma: 2.5}
	sequences := [[box], [gaussian], [contrast, gaussian, opacity, box],
		[CanvasFilterStep{kind: .blur, sigma: 1.2}], [gaussian, contrast, box],
		[CanvasFilterStep{kind: .blur, sigma: 1.2}], [box],
		[contrast, CanvasFilterStep{kind: .blur}, opacity, CanvasFilterStep{kind: .blur, sigma: .01}, box]]
	hashes := ['52a21c2bac4d4259', 'e9b398034919dbd9', 'a3b2ddfab2f04556', '8dbc9961e18faaa5',
		'a8230d732d6e0330', '0e53661aa81425c3', '7bb5c150a395bcf9', 'e126bfc9481ba799']
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := if i in [1, 2, 4, 7] { [f32(1), 1, 5, 4]! } else { [f32(0), 0, 7, 6]! }
		destination := match i {
			0 { [f32(4), 5, 30, 25]! }
			1 { [f32(4.25), 6.5, 25, 18]! }
			3 { [f32(10.25), 12.5, 28, 18]! }
			5 { [f32(10.25), 12.5, 2, 3]! }
			6 { [f32(10), 12, 7, 6]! }
			else { [f32(4.5), 6.25, 22, 16]! }
		}
		transform := if i == 4 { [f32(-1.1), 0, 0, .8, 42, 3]! }
			else if i == 6 { [f32(1), 0, 0, 1, .25, .75]! } else { image_test_identity }
		mode := match i { 0, 6 { BlendMode.src_over } 2 { .overlay } 3 { .multiply }
			5 { .plus_lighter } else { .src_in } }
		alpha := if i == 2 { f32(.65) } else if i in [5, 7] { f32(.7) } else { f32(1) }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [2, 3, 7], i in [2, 5, 7]), source, destination,
			i != 1, alpha, mode, image_test_clips(i in [1, 3, 5, 7]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'resampled source fixture ${i}'
	}
}

fn test_source_clipping_precedes_spatial_filters_and_preserves_draw_bounds() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
		offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
	sequences := [[gaussian], [gaussian], [contrast, shadow, opacity], [contrast, shadow],
		[gaussian], [CanvasFilterStep{...shadow, sigma: .01}], [gaussian],
		[contrast, CanvasFilterStep{kind: .blur}, opacity, gaussian, CanvasFilterStep{kind: .blur, sigma: 2.5}]]
	hashes := ['c6e6def672ae03e9', '1856d090e74e592c', 'da2274221967646b', '5fa502d06913b702',
		'62b1b888837ad40a', 'f00be8e39ec6bc7f', '62b1b888837ad40a', '98407a88886b2f75']
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := match i {
			0, 3 { [f32(1), 1, 7, 6]! }
			1, 7 { [f32(-2), -1, 10, 8]! }
			2 { [f32(-.25), .5, 6.75, 6]! }
			6 { [f32(0), 0, 100, 6]! }
			else { [f32(9), 0, 7, 6]! }
		}
		destination := match i {
			0, 3 { [f32(4), 6, 7, 6]! }
			1, 7 { [f32(4.25), 6.5, 25, 18]! }
			2 { [f32(4.5), 6.25, 22, 16]! }
			6 { [f32(-30), 5, 50, 18]! }
			else { [f32(10), 12, 7, 6]! }
		}
		mode := if i in [0, 5] { BlendMode.multiply } else if i == 2 { BlendMode.overlay } else { BlendMode.src_in }
		alpha := if i == 2 { f32(.65) } else if i in [3, 7] { f32(.7) } else { f32(1) }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, image_test_identity,
			image_test_bitmap(7, 6, i !in [0, 2, 7], i in [0, 2, 3, 7]), source, destination,
			true, alpha, mode, image_test_clips(i in [0, 1, 4, 5, 6, 7]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'clipped source fixture ${i}'
	}
}

fn test_near_integer_shadow_offsets_reduce_sampling_to_nearest() {
	image := CanvasBitmap{width: 2, height: 1, pitch: 8, premultiplied: true, display_p3: true,
		pixels: [u8(0), 0, 0, 255, 0, 0, 0, 1]}
	mut pixels := []u8{len: 24 * 16 * 4}
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, offset_x: 10.00099,
		offset_y: 4, color: 0xff000000}])
	assert draw_canvas_image_filtered(mut pixels, 24, 16, 96, 2, image_test_identity,
		image, [f32(0), 0, 2, 1]!, [f32(4), 6, 2, 1]!, true, f32(127) / f32(255), .src_over, [], filter, false)
	assert pixels[(10 * 24 + 15) * 4 + 3] == 0
	assert sha256.sum(pixels).hex() == 'd8f9957149e13daea2abd1cc604f651ba2d4ceb5ef921760f9077cb1be069f9d'
}

fn test_identity_blurs_keep_source_sampling_and_color_filters_deferred() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	zero := CanvasFilterStep{kind: .blur}
	tiny := CanvasFilterStep{kind: .blur, sigma: .001}
	sequences := [[contrast, zero, opacity], [contrast, tiny, opacity, zero, contrast],
		[zero, opacity, tiny, contrast], [contrast, tiny], [contrast, tiny], [contrast, zero, opacity, tiny]]
	hashes := ['66ea4382a30ae423', 'faf646ac30327c3f', 'e10325f572b4dc14',
		'e12c13dca8162f9f', 'f6e28ad1753237d4', 'c1ada75f25f9bac0']
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := if i in [0, 4] { [f32(0), 0, 7, 6]! }
			else if i == 5 { [f32(-2), -1, 10, 8]! } else { [f32(1), 1, 5, 4]! }
		destination := match i {
			2 { [f32(10.25), 12.5, 2, 3]! }
			4 { [f32(-8.002), 5, 7, 6]! }
			5 { [f32(4.25), 6.5, 25, 18]! }
			else { [f32(4.5), 6.25, 22, 16]! }
		}
		transform := if i == 3 { [f32(-1.1), 0, 0, .8, 42, 3]! } else { image_test_identity }
		alpha := if i == 1 { f32(.65) } else if i in [2, 5] { f32(.7) } else { f32(1) }
		mode := match i { 0 { BlendMode.overlay } 2 { .plus_lighter } 3 { .multiply } else { .src_in } }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [1, 5], i in [1, 2, 5]), source, destination,
			true, alpha, mode, image_test_clips(i in [1, 2, 3, 5]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'identity source fixture ${i}'
	}
}

fn test_identity_blurs_preserve_images_without_color_matrices() {
	zero := CanvasFilterStep{kind: .blur}
	tiny := CanvasFilterStep{kind: .blur, sigma: .001}
	hashes := ['fac95cda665447d0', '3dc171f15c4a6337', '4ec3f389f0ccf270',
		'41cedb613f3f59b3', 'f43245c7c409678f', '78e8496c23d32d03']
	for i in 0 .. hashes.len {
		mut pixels := image_test_background()
		source := if i in [1, 2, 4] { [f32(1), 1, 5, 4]! } else { [f32(0), 0, 7, 6]! }
		destination := if i in [1, 2] { [f32(10.25), 12.5, 2, 3]! }
			else if i == 5 { [f32(10), 12, 7, 6]! } else { [f32(4.5), 6.25, 22, 16]! }
		transform := if i == 4 { [f32(-1.1), 0, 0, .8, 42, 3]! }
			else if i == 5 { [f32(1), 0, 0, 1, .3, .7]! } else { image_test_identity }
		steps := if i == 2 { [zero, tiny] } else if i in [1, 3, 4] { [tiny] } else { [zero] }
		alpha := if i == 2 { f32(.7) } else if i == 3 { f32(.65) } else { f32(1) }
		mode := match i { 2 { BlendMode.plus_lighter } 3 { .src_in } 4 { .plus_darker } else { .src_over } }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i != 3, i == 2), source, destination, true, alpha,
			mode, image_test_clips(i in [2, 3]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'identity sampling fixture ${i}'
	}
}

fn test_nearly_integer_source_filters_preserve_native_sampling_shortcuts() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	tiny := CanvasFilterStep{kind: .blur, sigma: .001}
	blur := CanvasFilterStep{kind: .blur, sigma: 1.2}
	sequences := [[blur], [blur], [blur], [contrast, tiny, opacity, blur],
		[tiny], [blur], [blur], [opacity], [tiny], [tiny], [blur], [contrast, tiny, opacity, blur]]
	hashes := ['fa94d509cac7a3aa', 'd0e26776186b8bea', 'acc7141f085d1362', 'edddaf35caff87f0',
		'3c3fb2d670bf7693', '60aef21c9403b4ef', '0c4068f3faaac712', '61ae453832882d02',
		'd5ea576df832e18b', '35dc909ee4d6fb74', 'c143b26618f52631', 'f095ad3dcce7789e']
	for i, steps in sequences {
		mut pixels := image_test_background()
		source := if i < 4 || i >= 10 { [f32(0), 0, 7, 6]! } else { [f32(2), 2, 4, 3]! }
		destination := if i >= 10 { [f32(5.40032), 12.3341333333333, 5.60056, 7.9992]! }
			else if i < 4 { [f32(10.0004), 12.0006, 7.0007, 5.9994]! }
			else if i < 8 { [f32(6.0018), 8.0018, 4.0036, 3.0027]! } else { [f32(6), 8, 4.0024, 3.0018]! }
		alpha := if i in [2, 9, 11] { f32(.65) } else if i in [3, 5] { f32(.7) } else { f32(1) }
		mode := match i { 1, 3, 9, 10 { BlendMode.src_in } 2, 11 { .multiply } 5 { .plus_lighter }
			7 { .src } else { .src_over } }
		transform := if i >= 10 { [f32(1.25), 0, 0, .75, 3.25, 2.75]! } else { image_test_identity }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i in [0, 3, 5, 8], i in [2, 4, 5, 7, 8, 11]), source, destination,
			i < 4 || i == 8 || i >= 10, alpha, mode, image_test_clips(i in [1, 3, 5, 7, 9, 10]), new_canvas_filter(steps), false)
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'near-integer image fixture ${i}'
	}
}

fn test_linear_clearing_restore_uses_the_near_scale_sprite_inside_its_image() {
	image := CanvasBitmap{width: 4, height: 1, pitch: 16, premultiplied: true,
		pixels: [u8(0), 0, 0, 255, 0, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 255]}
	mut pixels := image_test_background()
	filter := new_canvas_filter([CanvasFilterStep{kind: .blur, sigma: .001},
		CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
			matrix: [f32(8), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!}}])
	assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, image_test_identity, image,
		[f32(2), 0, 2, 1]!, [f32(6), 6, 2.0018, 1]!, true, 1, .src_in,
		[rect_path(Rect{7, 6, 8, 7})], filter, false)
	assert pixels[(6 * 48 + 7) * 4] == 0
	assert sha256.sum(pixels).hex() == 'a95ab159f7e63159b0dd6f593b1f26b8ef1624f145c8e45f7d010e2c278e8f93'
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

fn test_scaled_integer_source_shadow_preserves_deferred_foreground() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	hashes := ['2bb81f3c940efdd1', if canvas_rgba_uses_legacy() { '1f1f586daef2c8bf' } else { '9d9fa7c17fc9bf77' }, '5e5361d693406941', 'a314c86fea2dc72a', 'b0cf78ae45b5d34a', 'b0b37ca26e9ec933', 'ecb21cc6ee1cdc4e', '5fe5ede2432aa2cc']
	for i in 0 .. hashes.len {
		mut pixels := image_test_background()
		source := if i in [1, 2, 4, 7] { [f32(1), 1, 5, 4]! } else { [f32(0), 0, 7, 6]! }
		destination := match i {
			0 { [f32(4), 5, 30, 25]! }
			1 { [f32(4.25), 6.5, 25, 18]! }
			3 { [f32(10.25), 12.5, 28, 18]! }
			5 { [f32(10.25), 12.5, 2, 3]! }
			6 { [f32(10), 12, 7, 6]! }
			else { [f32(4.5), 6.25, 22, 16]! }
		}
		transform := if i == 4 { [f32(-1.1), 0, 0, .8, 42, 3]! }
			else if i == 6 { [f32(1), 0, 0, 1, .25, .75]! } else { image_test_identity }
		mode := match i { 0, 6 { BlendMode.src_over } 2 { .overlay } 3 { .multiply }
			5 { .plus_lighter } else { .src_in } }
		alpha := if i == 2 { f32(.65) } else if i in [5, 7] { f32(.7) } else { f32(1) }
		sigma := if i in [1, 2] { f32(.8) } else if i in [3, 5] { f32(1.2) } else { f32(2.5) }
		mut steps := []CanvasFilterStep{}
		if i in [2, 4, 7] { steps << contrast }
		steps << CanvasFilterStep{kind: .drop_shadow, sigma: sigma,
			offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
		if i in [2, 7] { steps << opacity }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [2, 3, 7], i in [2, 5]), source, destination,
			i != 1, alpha, mode, image_test_clips(i in [1, 3, 5, 7]), new_canvas_filter(steps), false), 'scaled shadow fixture ${i} declined'
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'scaled shadow fixture ${i}'
	}
}

fn test_near_integer_shadow_blur_keeps_raw_subset_and_original_foreground() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	hashes := ['69bc99f80ec99582', '4e951a3d41351d05', 'a51dd6ce8df7e098', 'aa1915a0e5923229', 'a012597b325882fd', 'aff305b8a0ccc68b', 'abdab1d4f3a93229']
	for i in 0 .. hashes.len {
		mut pixels := image_test_background()
		source := if i in [3, 4] { [f32(2), 2, 4, 3]! } else { [f32(0), 0, 7, 6]! }
		destination := if i >= 5 { [f32(5.40032), 12.3341333333333, 5.60056, 7.9992]! }
			else if i < 3 { [f32(10.0004), 12.0006, 7.0007, 5.9994]! }
			else { [f32(6), 8, 4.0024, 3.0018]! }
		transform := if i >= 5 { [f32(1.25), 0, 0, .75, 3.25, 2.75]! } else { image_test_identity }
		mode := match i { 0 { BlendMode.src_over } 2, 6 { .multiply } 3 { .plus_lighter } else { .src_in } }
		alpha := if i in [2, 4, 6] { f32(.65) } else { f32(1) }
		mut steps := []CanvasFilterStep{}
		if i in [2, 6] { steps << contrast }
		steps << CanvasFilterStep{kind: .drop_shadow, sigma: 1.2,
			offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
		if i in [2, 6] { steps << opacity }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i in [0, 3], i in [2, 3, 6]), source, destination,
			i != 4, alpha, mode, image_test_clips(i in [1, 3, 4, 5]), new_canvas_filter(steps), false),
			'near shadow fixture ${i} declined'
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'near shadow fixture ${i}'
	}
}

fn test_identity_and_invalid_source_image_shadows_defer_tint_and_sampling() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	hashes := ['68ec54837de261df', if canvas_rgba_uses_legacy() { '7a773e55fa8b6342' } else { '94c9d6dfcf804982' }, '8e8005e8ba8b0db1', '641353e85eba5b86', '47d575499b0cd948', 'f0d9a6813b237621', '6744041f50e2ed13', if canvas_rgba_uses_legacy() { '25ca27a80dca1e6c' } else { '92ad67f96173f5f1' }]
	for i in 0 .. hashes.len {
		mut pixels := image_test_background()
		source := if i in [1, 2, 3] { [f32(1), 1, 5, 4]! }
			else if i == 7 { [f32(2), 2, 4, 3]! } else { [f32(0), 0, 7, 6]! }
		destination := match i {
			0 { [f32(4), 5, 30, 25]! }
			1 { [f32(4.25), 6.5, 25, 18]! }
			4 { [f32(10.25), 12.5, 2, 3]! }
			5 { [f32(10.25), 12.5, 28, 18]! }
			6 { [f32(10.0004), 12.0006, 7.0007, 5.9994]! }
			else { [f32(4.5), 6.25, 22, 16]! }
		}
		transform := if i == 7 { [f32(1.25), 0, 0, .75, 3.25, 2.75]! } else { image_test_identity }
		mode := match i { 0, 6 { BlendMode.src_over } 2 { .overlay } 4 { .plus_lighter } 5 { .multiply } else { .src_in } }
		alpha := if i in [2, 3] { f32(.65) } else if i == 4 { f32(.7) } else { f32(1) }
		sigma := if i in [3, 4, 5] { f32(-1) } else if i in [0, 7] { f32(0) } else { f32(.000001) }
		mut steps := []CanvasFilterStep{}
		if i in [2, 3] { steps << contrast }
		steps << CanvasFilterStep{kind: .drop_shadow, sigma: sigma,
			offset_x: if i == 7 { f32(4) } else if i in [1, 5] { f32(5) } else { f32(5.25) },
			offset_y: if i == 7 { f32(4) } else if i in [1, 5] { f32(-4) } else { f32(-3.75) }, color: 0x805030e0}
		if i in [2, 3] { steps << opacity }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [2, 3, 5], i in [2, 3, 4]), source, destination,
			i !in [1, 5, 7], alpha, mode, image_test_clips(i in [1, 3, 4, 5]), new_canvas_filter(steps), false),
			'identity shadow fixture ${i} declined'
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'identity shadow fixture ${i}'
	}
}

fn test_offscreen_shadow_does_not_shift_the_identity_merge_origin() {
	mut pixels := $embed_file('testdata/identity-shadow-origin-background.rgba').to_bytes()
	image := CanvasBitmap{width: 15, height: 24, pitch: 64, premultiplied: true, display_p3: true,
		pixels: $embed_file('testdata/identity-shadow-origin-source.rgba').to_bytes()}
	filters := new_canvas_filter([
		CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
			matrix: [f32(0), 0, 0, 0, .5, 0, 0, 0, 0, .5, 0, 0, 0, 0, .5, 0, 0, 0, 1, 0]!}},
		CanvasFilterStep{kind: .drop_shadow, sigma: -1, offset_x: 6, offset_y: 15, color: 2399918666},
		CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
			matrix: [f32(.58240926), 0, 0, 0, .20879537, 0, .58240926, 0, 0, .20879537,
				0, 0, .58240926, 0, .20879537, 0, 0, 0, 1, 0]!}},
	])
	assert draw_canvas_image_filtered(mut pixels, 84, 24, 344, 1,
		[f32(1.5043701), 0, 0, -2.1267667, 3.25, 19.2]!, image, [f32(1), 13, 5, 2]!,
		[f32(2.4294972), 4.8504453, 24.454557, 2.9388463]!, true, 1, .src_over, [], filters, false)
	assert pixels[5 * 344 + 35 * 4] == 128
	assert sha256.sum(pixels).hex()[..16] == '6918c091a7f3c206'
}

fn test_nearest_source_shadows_resolve_before_fractional_offset() {
	contrast := image_test_contrast_filter()
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	hashes := $if linux { ['74ef0767c101390a', 'b0b67dba3bb87d45', '741e193007ca6ec3', '9a8d7906fd102a19', 'e00d7577ca66d313', '1ad1f894abb926c3', '5581e3d64779e918', 'a752fab16a4109bb', '98ab8774ecaffba1', '58098840e4e0f6d9'] } $else { ['58dcb346943e34ad', '9b7978b9155b68b7', 'a005d44326d848c9', '75f9f4859dba60e3', '2e3b1a72ba273cd9', '2e367dd716646a39', '4e105e2ca7a7eea7', '34955f83e4426d58', '30aa689b07f085a0', '58098840e4e0f6d9'] }
	for i in 0 .. hashes.len {
		mut pixels := image_test_background()
		source := if i in [1, 2, 3, 6] { [f32(1), 1, 5, 4]! }
			else if i == 7 { [f32(2), 2, 4, 3]! } else { [f32(0), 0, 7, 6]! }
		destination := match i {
			0 { [f32(4), 5, 30, 25]! }
			1 { [f32(4.25), 6.5, 25, 18]! }
			4 { [f32(10.25), 12.5, 2, 3]! }
			5 { [f32(10.25), 12.5, 28, 18]! }
			8 { [f32(-30), 6, 24, 18]! }
			else { [f32(4.5), 6.25, 22, 16]! }
		}
		transform := if i == 6 { [f32(-1.1), 0, 0, .8, 42, 3]! }
			else if i == 7 { [f32(1.25), 0, 0, .75, 3.25, 2.75]! } else { image_test_identity }
		mode := match i { 0 { BlendMode.src_over } 2 { .overlay } 4 { .plus_lighter } 5 { .multiply } else { .src_in } }
		alpha := if i in [2, 3] { f32(.65) } else if i in [4, 7] { f32(.7) }
			else if i == 5 { f32(.999) } else { f32(1) }
		sigma := if i in [3, 4] { f32(-1) } else if i in [1, 2, 5] { f32(.000001) } else { f32(0) }
		offset := match i {
			6 { Point{3.5, -2.25} } 7 { Point{.25, -.75} } 8 { Point{34.5, -2.25} }
			9 { Point{150.25, -100} } else { Point{5.25, -3.75} }
		}
		mut steps := []CanvasFilterStep{}
		if i in [2, 3, 6, 8, 9] { steps << contrast }
		steps << CanvasFilterStep{kind: .drop_shadow, sigma: sigma,
			offset_x: offset.x, offset_y: offset.y, color: 0x805030e0}
		if i in [2, 3, 8, 9] { steps << opacity }
		assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
			image_test_bitmap(7, 6, i !in [2, 3, 5], i in [2, 3, 4, 7]), source, destination,
			false, alpha, mode, image_test_clips(i in [1, 3, 4, 5, 8, 9]), new_canvas_filter(steps), false),
			'resolved shadow fixture ${i} declined'
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'resolved shadow fixture ${i}'
	}
}

fn test_thin_nearest_shadow_resolve_preserves_native_coverage() {
	image := CanvasBitmap{width: 24, height: 2, pitch: 100, premultiplied: true, display_p3: true,
		pixels: $embed_file('testdata/resolved-shadow-thin-source.rgba').to_bytes()}
	identity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!}}
	for i in 0 .. 2 {
		mut pixels := $embed_file('testdata/resolved-shadow-thin-background.rgba').to_bytes()
		mut steps := [identity, CanvasFilterStep{kind: .drop_shadow, sigma: -1,
			offset_x: -16, offset_y: 10, color: 0xffffffff}]
		if i == 1 {
			steps << identity
			steps << CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
				matrix: [f32(-.0664451), .47126946, .10513631, -.90223706, .2727217,
					-.21826614, -.57720643, .41614532, .73150754, -.86200744,
					-.14551322, -.39294574, -.6733888, .11890532, -.2589099, 0, 0, 0, .16235755, 0]!}}
		}
		assert draw_canvas_image_filtered(mut pixels, 87, 8, 352, 1,
			[f32(1.9846058), 0, 0, -.2999618, 3.25, 6.4]!, image, [f32(5), 0, 16, 2]!,
			[f32(18.515005), -1.4122566, 85.50765, 2.448695]!, false, 1,
			if i == 0 { .src } else { .src_atop }, [], new_canvas_filter(steps), false)
		expected := $if linux { ['a1efef67211fbbde', 'aff78d507ddefba6'] } $else { ['b54173ae0d037c96', '09ffe213e3642515'] }
		assert sha256.sum(pixels).hex()[..16] == expected[i]
	}
}

// Captured independently by native_aligned_image_filter_hashes.py. Raw
// pixel-aligned sources retain alpha/color effects; fractional sources draw
// into MakeFromImage's AA surface before entering the mixed filter graph.
fn test_source_image_mixed_spatial_graphs_match_native() {
 contrast := image_test_contrast_filter()
 opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
  matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
 gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
 tiny := CanvasFilterStep{kind: .blur, sigma: .01}
 shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
  offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
 identity := CanvasFilterStep{...shadow, sigma: 0}
 shadow2 := CanvasFilterStep{...shadow, sigma: .8, offset_x: -7.25, offset_y: 4.5}
 small := CanvasFilterStep{...shadow, sigma: .8}
 sequences := [
  [gaussian, shadow], [shadow, gaussian], [shadow, shadow2],
  [contrast, identity, opacity, tiny, small], [contrast, shadow, gaussian, opacity],
  [opacity, identity, contrast, CanvasFilterStep{...shadow, sigma: .01}],
  [gaussian, shadow], [shadow, gaussian], [shadow, shadow2],
  [shadow, contrast, gaussian, small], [contrast, identity, opacity, tiny, small],
  [shadow, gaussian], [shadow, gaussian], [shadow, gaussian],
 ]
 hashes := $if linux { ['a6eff4e4d6d0b525', '9736c314d18243e4', '21edf031b5cad9bf', '4f87fbb4a116f74d', '0a4d5b84834e14f6', '3413bb7c9b0e9950', '206ed0f93c797611', '7d91d1dd5fc4ea7d', 'd1881a087ec36965', 'c22b2b4fdcb9c1c8', 'a72cc96950afdcd1', 'f68b7870dc82135b', '62b1b888837ad40a', '62b1b888837ad40a'] } $else { ['a6eff4e4d6d0b525', '9736c314d18243e4', '21edf031b5cad9bf', '4f87fbb4a116f74d', '0a4d5b84834e14f6', '3413bb7c9b0e9950', '9aae5da5398fe1e4', '7d91d1dd5fc4ea7d', 'd1881a087ec36965', 'ff49a0bb8b31af28', 'a72cc96950afdcd1', 'f68b7870dc82135b', '62b1b888837ad40a', '62b1b888837ad40a'] }
 for i, steps in sequences {
  mut pixels := image_test_background()
  source := match i {
   1 { [f32(1), 1, 5, 4]! }
   6, 10 { [f32(.25), .5, 6.25, 5]! }
   7, 8, 9 { [f32(1.25), 1.5, 4.5, 3.75]! }
   11 { [f32(-2), -1, 7, 6]! }
   12 { [f32(10), 10, 7, 6]! }
   else { [f32(0), 0, 7, 6]! }
  }
  destination := match i {
   1 { [f32(4), 6, 5, 4]! }
   6, 10 { [f32(10.25), 12.5, 28, 18]! }
   7, 8, 9 { [f32(4.5), 6.25, 22, 16]! }
   11, 12 { [f32(4), 6, 7, 6]! }
   else { [f32(10), 12, 7, 6]! }
  }
  transform := match i {
   1 { [f32(1), 0, 0, 1, 3, -2]! }
   6, 10 { [f32(1.25), 0, 0, .75, 2, 4]! }
   9 { [f32(-1.1), 0, 0, .8, 42, 3]! }
   else { image_test_identity }
  }
  mode := match i {
   1, 6, 11, 12, 13 { BlendMode.src_in }
   2, 7 { .overlay }
   5, 8 { .multiply }
   4, 9 { .src_out }
   10 { .plus_lighter }
   else { .src_over }
  }
  alpha := match i { 1, 4, 8 { f32(.65) } 2, 10 { f32(.7) } 13 { f32(0) } else { f32(1) } }
  assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, if i == 4 { 1 } else { 2 },
   transform, image_test_bitmap(7, 6, i !in [1, 2, 5, 7, 8, 10], i in [1, 3, 7, 10]),
   source, destination, true, alpha, mode, image_test_clips(i in [1, 4, 5, 6, 8, 10, 11, 12, 13]),
   new_canvas_filter(steps), false), 'source chain ${i} declined'
  assert sha256.sum(pixels).hex()[..16] == hashes[i], 'source chain ${i}'
 }
}

fn test_resampled_source_chains_resolve_at_first_real_blur() {
 contrast := image_test_contrast_filter()
 opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
  matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
 gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
 box := CanvasFilterStep{kind: .blur, sigma: 2.5}
 tiny := CanvasFilterStep{kind: .blur, sigma: .01}
 shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
  offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
 small := CanvasFilterStep{...shadow, sigma: .8}
 sequences := [
  [gaussian, shadow], [contrast, gaussian, shadow, opacity], [box, contrast, small],
  [gaussian, CanvasFilterStep{...shadow, sigma: 1.2}],
  [contrast, tiny, gaussian, opacity, shadow],
  [gaussian, shadow, CanvasFilterStep{...small, offset_x: -7.25, offset_y: 4.5}],
  [box, contrast, small], [gaussian, shadow],
 ]
 hashes := ['96377cc5e9c1be3b', '5a943a8884b2705e', 'd6368e170d652582', '7376c5a0cf4a2011', '75dc62f04fca90f3', '48ff3cff3719f678', 'e16b6f85b42e091e', '846b048d1a7a0879']
 for i, steps in sequences {
  mut pixels := image_test_background()
  source := if i in [1, 2, 6] { [f32(1), 1, 5, 4]! }
   else if i == 7 { [f32(-2), -1, 7, 6]! } else { [f32(0), 0, 7, 6]! }
  destination := match i {
   0 { [f32(4), 5, 30, 25]! }
   1, 6, 7 { [f32(4.25), 6.5, 25, 18]! }
   3 { [f32(10.0004), 12.0006, 7.0007, 5.9994]! }
   4 { [f32(10.25), 12.5, 2, 3]! }
   else { [f32(4.5), 6.25, 22, 16]! }
  }
  transform := if i == 2 { [f32(-1.1), 0, 0, .8, 42, 3]! }
   else if i in [4, 7] { [f32(1.25), 0, 0, .75, 3.25, 2.75]! } else { image_test_identity }
  mode := match i { 1, 7 { BlendMode.src_in } 2 { .src_out } 4 { .multiply }
   5 { .src_atop } 6 { .src } else { .src_over } }
  alpha := if i == 1 { f32(.65) } else if i in [2, 4, 5] { f32(.7) } else { f32(1) }
  assert draw_canvas_image_filtered(mut pixels, 48, 40, 192, 2, transform,
   image_test_bitmap(7, 6, i !in [1, 4, 5], i in [1, 4]), source, destination,
   i != 1, alpha, mode, image_test_clips(i in [1, 4, 6, 7]), new_canvas_filter(steps), false),
   'resampled chain ${i} declined'
  assert sha256.sum(pixels).hex()[..16] == hashes[i], 'resampled chain ${i}'
 }
}

fn test_resampled_source_shadow_before_real_blur_preserves_destination() {
 shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5,
  offset_x: 5.25, offset_y: -3.75, color: 0x805030e0}
 blur := CanvasFilterStep{kind: .blur, sigma: .8}
 tiny := CanvasFilterStep{kind: .blur, sigma: .01}
 for steps in [[shadow, blur], [tiny, shadow, blur]] {
  mut pixels := image_test_background()
  before := pixels.clone()
  assert !draw_canvas_image_filtered(mut pixels, 48, 40, 192, 1, image_test_identity,
   image_test_bitmap(7, 6, false, true), [f32(0), 0, 7, 6]!, [f32(4), 5, 30, 25]!,
   true, .65, .src_over, [], new_canvas_filter(steps), false)
  assert pixels == before
 }
}

struct ImageRequestClipFixture {
 segments []f32
 even_odd bool
}

struct ImageRequestStepFixture {
 kind int
 matrix [20]f32
 clamp bool
 sigma f32
 offset_x f32
 offset_y f32
 color u32
}

struct ImageRequestFixture {
 width int
 height int
 pitch int
 alpha_type int
 transform [6]f32
 source [4]f32
 destination [4]f32
 global_alpha f32
 composite int
 image_width int
 image_height int
 image_pitch int
 image_premultiplied bool
 image_display_p3 bool
 clips []ImageRequestClipFixture
 filters []ImageRequestStepFixture
}

// Each shadow branch can request a different first-blur resolve rectangle.
// The full source cannot be sampled once and reused: the strict/clamp/decal
// choice and its edge pixels depend on the branch's actual sample bounds.
fn test_resampled_chain_source_resolution_uses_each_blur_request() {
 inputs := [
  $embed_file('@VMODROOT/cpuraster/testdata/resampled-request-prod.json').to_string(),
  $embed_file('@VMODROOT/cpuraster/testdata/resampled-request-default.json').to_string(),
 ]
 sources := [
  $embed_file('@VMODROOT/cpuraster/testdata/resampled-request-prod-source.rgba').to_bytes(),
  $embed_file('@VMODROOT/cpuraster/testdata/resampled-request-default-source.rgba').to_bytes(),
 ]
 backgrounds := [
  $embed_file('@VMODROOT/cpuraster/testdata/resampled-request-prod-background.rgba').to_bytes(),
  $embed_file('@VMODROOT/cpuraster/testdata/resampled-request-default-background.rgba').to_bytes(),
 ]
 hashes := $if linux { ['647ddc0897133c6d', '9e770877597b62d4'] } $else { ['647ddc0897133c6d', 'f893a84730298ea1'] }
 for i, input in inputs {
  c := json2.decode[ImageRequestFixture](input) or { panic(err) }
  steps := c.filters.map(CanvasFilterStep{
   kind: match it.kind { 0 { CanvasFilterKind.blur } 1 { .drop_shadow } else { .matrix } }
   matrix: MatrixColorFilter{it.matrix, it.clamp}
   sigma: it.sigma, offset_x: it.offset_x, offset_y: it.offset_y, color: it.color
  })
  clips := c.clips.map(canvas_path(it.segments, it.even_odd))
  mut pixels := backgrounds[i].clone()
  assert draw_canvas_image_filtered(mut pixels, c.width, c.height, c.pitch, c.alpha_type,
   c.transform, CanvasBitmap{pixels: sources[i], width: c.image_width, height: c.image_height,
    pitch: c.image_pitch, premultiplied: c.image_premultiplied, display_p3: c.image_display_p3},
   c.source, c.destination, true, c.global_alpha, canvas_blend_mode(c.composite) or { panic('mode') },
   clips, new_canvas_filter(steps), false)
  assert sha256.sum(pixels).hex()[..16] == hashes[i]
 }
}
