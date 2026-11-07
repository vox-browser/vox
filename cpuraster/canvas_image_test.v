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

// Hashes of vox_skia_canvas_path()'s bitmap commands with LibWeb Skia for
// the same cases (test_cpu_raster.sh compares random ones).
fn test_clears_match_skia() {
	// A hard rect clip, then Src of transparent black.
	assert clear_test_hash(image_test_identity, [f32(3.5), 4.25, 30, 20]!, 0, false) == '4862b730d1fb2247'
	// Opaque black (alpha: false) is source-over, under a flipping scale.
	assert clear_test_hash([f32(1.5), 0, 0, -1.2, 2, 39]!, [f32(2), 3, 20, 15]!, 0xff000000,
		false) == '438681b38b121c8c'
	// Inside an anti-aliased clip.
	assert clear_test_hash(image_test_identity, [f32(0), 0, 48, 40]!, 0, true) == '62b1b888837ad40a'
}

fn test_sprite_images_match_skia() {
	// Unscaled premultiplied images: Sprite_D32_S32, the Memcpy sprite for
	// copy and blit_row_s32a_blend at half alpha.
	assert image_test_hash(ImageTestCase{
		destination: [f32(10), 12, 7, 6]!
	}) == 'eba880bbda5f6f4a'
	assert image_test_hash(ImageTestCase{
		mode:        .src
		destination: [f32(10), 12, 7, 6]!
	}) == '96f513ac0f45d7a2'
	assert image_test_hash(ImageTestCase{
		alpha:       0.5
		destination: [f32(10), 12, 7, 6]!
	}) == '0495a4388ca940c9'
	// Display P3: SkRasterPipelineSpriteBlitter.
	assert image_test_hash(ImageTestCase{
		display_p3:  true
		destination: [f32(10), 12, 7, 6]!
	}) == 'd4051cafcbbe1366'
	// An anti-aliased clip that cuts the sprite takes the shader instead.
	assert image_test_hash(ImageTestCase{
		destination: [f32(30), 14, 7, 6]!
		clip:        true
	}) == '7a1823380c32d1fe'
}

fn test_scaled_images_match_skia() {
	// Nearest and bilinear legacy contexts, a bilinear subset away from the
	// origin, and a source rect past the image.
	assert image_test_hash(ImageTestCase{
		destination: [f32(5), 5, 20, 14]!
	}) == '3e8084e20b39a7f3'
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		destination: [f32(5), 5, 20, 14]!
	}) == '9c725c14254b2f62'
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		destination: [f32(6), 4, 30, 20]!
		source:      [f32(2), 1, 4, 3]!
	}) == '24d847ccb95ac95d'
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		destination: [f32(4), 3, 30, 25]!
		source:      [f32(-2), -1, 6, 5]!
	}) == '48cbeda9149b9d90'
	// Unpremultiplied: the raster pipeline's lowp bilerp_clamp_8888.
	assert image_test_hash(ImageTestCase{
		smoothing:     true
		premultiplied: false
		destination:   [f32(5.5), 5, 21, 14]!
	}) == '090261b8b1015058'
	// A quarter turn keeps rects rects: the nearest affine legacy procs.
	assert image_test_hash(ImageTestCase{
		transform:   [f32(0), 1, -1, 0, 44, 2]!
		destination: [f32(5), 5, 20, 14]!
	}) == 'd256feaf2557e392'
	// Multiply at partial alpha through the pipeline.
	assert image_test_hash(ImageTestCase{
		smoothing:   true
		mode:        .multiply
		alpha:       0.8
		destination: [f32(5), 5, 20, 14]!
	}) == '756d48e5937f902d'
}

// A rotation fills a non-anti-aliased path, which is not ported: the draw
// declines without touching the pixels.
fn test_rotated_images_decline() {
	mut px := image_test_background()
	before := px.clone()
	assert !draw_canvas_image(mut px, 48, 40, 192, 2, [f32(0.9), 0.4, -0.4, 0.9, 5, 2]!, image_test_bitmap(7,
		6, true, false), [f32(0), 0, 7, 6]!, [f32(5), 5, 20, 14]!, true, 1, .src_over, [])
	assert px == before
}
