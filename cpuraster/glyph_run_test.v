module cpuraster

import crypto.sha256
import os

fn glyph_test_background() []u8 {
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

const glyph_test_emoji = '/System/Library/Fonts/Apple Color Emoji.ttc'

fn glyph_test_font(name string) string {
	if name == 'emoji' {
		return glyph_test_emoji
	}
	return os.join_path(@VMODROOT, match name {
		'ahem' { 'Tests/Browser/Brave/resources/Ahem.ttf' }
		else { 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf' }
	})
}

struct GlyphTestCase {
	font        string = 'noto'
	size        f32
	glyphs      []u16
	positions   []f32
	translation [2]f32
	// The canvas transform; all zeros is the identity.
	transform  [6]f32
	color      u32 = 0xff000000
	alpha      f32 = 1
	mode       BlendMode = .src_over
	clip       bool
	gradient   bool
	alpha_type int = 2
}

fn glyph_test_run(c GlyphTestCase) CanvasGlyphRun {
	return CanvasGlyphRun{
		font_path:   glyph_test_font(c.font)
		font_size:   c.size
		glyphs:      c.glyphs
		positions:   c.positions
		translation: c.translation
	}
}

fn glyph_test_draw(c GlyphTestCase, mut px []u8) bool {
	transform := if c.transform == [6]f32{} { [f32(1), 0, 0, 1, 0, 0]! } else { c.transform }
	mut clips := []Path{}
	if c.clip {
		mut b := PathBuilder{}
		b.move_to(2, 3)
		b.line_to(45.5, 10.25)
		b.line_to(20.5, 38)
		b.close()
		clips << b.detach()
	}
	style := if c.gradient {
		?CanvasPaintStyle(CanvasGradient{
			kind:  1
			x0:    2
			x1:    44
			y1:    30
			stops: [f32(0), 1, 0, 0, 1, 0.6, 0, 0.5, 1, 0.8, 1, 0.2, 0.9, 0.1, 1]
		})
	} else {
		?CanvasPaintStyle(none)
	}
	return fill_canvas_glyphs(mut px, 48, 40, 192, c.alpha_type, glyph_test_run(c), transform,
		c.color, style, c.alpha, c.mode, clips, none)
}

// The hash of the pixels after the run, which must have drawn something.
fn glyph_test_hash(c GlyphTestCase) string {
	mut px := glyph_test_background()
	assert glyph_test_draw(c, mut px)
	mut untouched := glyph_test_background()
	if c.alpha_type != 2 {
		premultiply_rows(mut untouched, 48, 40, 192)
	}
	assert px != untouched
	return sha256.sum(px).hex()[..16]
}

// Hashes of vox_skia_canvas_glyphs()'s output with LibWeb Skia for the same
// runs (test_cpu_raster.sh compares random ones). The masks come from
// CoreText, so this needs macOS.
fn test_glyph_runs_match_skia() {
	$if !macos {
		return
	}
	// Black text at quarter-pixel phases on a premultiplied canvas.
	assert glyph_test_hash(GlyphTestCase{
		size:        13.3
		glyphs:      [u16(5), 9, 12, 7, 18]
		positions:   [f32(0), 0, 7.3, 0, 14.55, 0, 21.8, 0, 29.05, 0]
		translation: [f32(3.25), 22.6]!
	}) == '5c029154c20a02ec'
	// Translucent color under a rotation, onto unpremultiplied pixels.
	assert glyph_test_hash(GlyphTestCase{
		size:        17
		glyphs:      [u16(11), 3, 14, 6]
		positions:   [f32(0), 0, 9.1, 0.5, 18.2, 0, 27.4, -0.25]
		translation: [f32(2), 18]!
		transform:   [f32(0.9), 0.4, -0.4, 0.9, 6, -2]!
		color:       0xc02060e0
		alpha:       0.7
		alpha_type:  1
	}) == 'bb25e7c802157561'
	// A gradient (its average stop color selects the mask gamma) through an
	// anti-aliased clip with multiply.
	assert glyph_test_hash(GlyphTestCase{
		size:        21
		glyphs:      [u16(8), 10, 4]
		positions:   [f32(0), 0, 12, 0, 24.5, 0]
		translation: [f32(4), 30]!
		alpha:       0.9
		mode:        .multiply
		clip:        true
		gradient:    true
	}) == '1a09d6db8bd6a7c9'
	// A flipped, skewed transform: the Givens rotation and remaining matrix.
	assert glyph_test_hash(GlyphTestCase{
		size:        15
		glyphs:      [u16(13), 16, 2, 19]
		positions:   [f32(0), 0, 8, 0, 16, 0, 24, 0]
		translation: [f32(2), 12]!
		transform:   [f32(-1.2), 0.3, 0.2, 1.1, 46, 8]!
		color:       0xff40c020
	}) == '831c7b38d8ab6625'
	// Ahem's boxes, half transparent, clipped.
	assert glyph_test_hash(GlyphTestCase{
		font:        'ahem'
		size:        9.5
		glyphs:      [u16(40), 41, 42]
		positions:   [f32(0), 0, 10.25, 0, 20.5, 0]
		translation: [f32(5.6), 33.4]!
		color:       0x80ff8000
		clip:        true
		alpha_type:  1
	}) == '8c19c5f6d4f57022'
}

// Glyphs over 256 pixels per em are filled as their 64-point outlines:
// under the concatenated canvas matrix for a solid color, and mapped first
// when a gradient keeps the canvas matrix.
fn test_path_glyph_runs_match_skia() {
	$if !macos {
		return
	}
	assert glyph_test_hash(GlyphTestCase{
		size:        300
		glyphs:      [u16(5), 9]
		positions:   [f32(0), 0, 160.5, 0.25]
		translation: [f32(-30), 140]!
		color:       0xff2050a0
		alpha:       0.85
		alpha_type:  1
	}) == '3beb1f538036b195'
	assert glyph_test_hash(GlyphTestCase{
		size:        20
		glyphs:      [u16(9)]
		positions:   [f32(-0.3), 0.4]
		translation: [f32(-3.5), 9]!
		transform:   [f32(14), 3, -2, 15, 0, 0]!
		clip:        true
		gradient:    true
	}) == '15ff405c7a9e0e08'
}

// Color glyphs are CoreText's premultiplied images drawn as sprites: through
// Sprite_D32_S32, the raster pipeline sprite blitter for destination-in (an
// opaque paint that leaves A8 masks a null blitter), and an image shader
// where an anti-aliased clip cuts the sprite; past 256 pixels per em they
// have no outline and stay masks.
fn test_color_glyph_runs_match_skia() {
	$if !macos {
		return
	}
	if !os.is_file(glyph_test_emoji) {
		return
	}
	assert glyph_test_hash(GlyphTestCase{
		font:        'emoji'
		size:        20
		glyphs:      [u16(1500), 1700]
		positions:   [f32(0), 0, 21.3, 0.5]
		translation: [f32(2.5), 30]!
	}) == 'e781cda46681481c'
	assert glyph_test_hash(GlyphTestCase{
		font:        'emoji'
		size:        18
		glyphs:      [u16(1600)]
		positions:   [f32(0), 0]
		translation: [f32(14.2), 28]!
		alpha:       0.6
		mode:        .dst_in
		clip:        true
		alpha_type:  1
	}) == '015ba13270345fc7'
	assert glyph_test_hash(GlyphTestCase{
		font:        'emoji'
		size:        300
		glyphs:      [u16(1800)]
		positions:   [f32(0), 0]
		translation: [f32(-80), 120]!
		color:       0xff3366cc
		alpha:       0.9
		gradient:    true
	}) == 'e6ace4a9ca3c9dff'
}

// Faces past the first and missing files decline without touching the
// pixels.
fn test_unported_glyph_runs_decline() {
	$if !macos {
		return
	}
	for c in [
		GlyphTestCase{
			font:      'missing'
			size:      12
			glyphs:    [u16(5)]
			positions: [f32(0), 0]
		},
	] {
		mut px := glyph_test_background()
		before := px.clone()
		run := if c.font == 'missing' {
			CanvasGlyphRun{
				...glyph_test_run(c)
				font_path: '/nonexistent/font.ttf'
			}
		} else {
			glyph_test_run(c)
		}
		assert !fill_canvas_glyphs(mut px, 48, 40, 192, 1, run, if c.transform == [6]f32{} {
			[f32(1), 0, 0, 1, 0, 0]!
		} else {
			c.transform
		}, c.color, none, 1, .src_over, [], none)
		assert px == before
	}
	mut px := glyph_test_background()
	before := px.clone()
	assert !fill_canvas_glyphs(mut px, 48, 40, 192, 1, CanvasGlyphRun{
		...glyph_test_run(GlyphTestCase{
			size:      12
			glyphs:    [u16(5)]
			positions: [f32(0), 0]
		})
		face_index: 1
	}, [f32(1), 0, 0, 1, 0, 0]!, 0xff000000, none, 1, .src_over, [], none)
	assert px == before
}

// The mask gamma tables match SkTMaskGamma<3, 3, 3>(0.5, sRGB): linear at
// the white end, full coverage always 255.
fn test_mask_gamma_tables() {
	assert mask_gamma_tables.len == 8
	for table in mask_gamma_tables {
		assert table[0] == 0
		assert table[255] == 255
	}
}
