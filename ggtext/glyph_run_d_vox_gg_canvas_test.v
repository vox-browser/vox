// vtest build: macos && vox_gg_canvas?
module ggtext

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas

#flag darwin -framework CoreText -framework CoreFoundation
#include <CoreText/CoreText.h>

fn C.CFStringCreateWithCString(allocator voidptr, text &char, encoding u32) voidptr
fn C.CTFontCreateWithName(name voidptr, size f64, matrix voidptr) voidptr
fn C.CFRelease(ref voidptr)

const utf8_encoding = u32(0x08000100)

const identity = [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!

const run_glyphs = [u16(36), 37, 38]

const run_positions = [f32(0), 0, 10.3, 0, 21.7, 0]

const background = u32(0xfff0e6dc)

const padding = u32(0x12345678)

fn arial_ct_font() voidptr {
	name := C.CFStringCreateWithCString(unsafe { nil }, c'ArialMT', utf8_encoding)
	font := C.CTFontCreateWithName(name, 16, unsafe { nil })
	C.CFRelease(name)
	return font
}

// A 40x24 tile in a 48-pixel-wide buffer whose padding columns hold a marker.
fn tile() []u32 {
	return []u32{len: 48 * 24, init: if index % 48 < 40 { background } else { padding }}
}

// Draws the run with subpixel antialiasing and slight hinting (edging 2,
// hinting 1) and the bridge's Chromium surface properties (contrast and
// gamma 0).
fn draw_tile(ct_font voidptr, edging i32, flags i32, color u32) (i32, []u32) {
	mut pixels := tile()
	drawn := glyph_run(pixels.data, 40, 24, 48, ct_font, 16, 1, 0, edging, 1, flags,
		run_glyphs.data, run_positions.data, i32(run_glyphs.len), 3.25, 18, &identity[0],
		color, 0, 0)
	return drawn, pixels
}

fn test_glyph_run_matches_gg_canvas_in_a_strided_bgra_tile() {
	ct_font := arial_ct_font()
	assert ct_font != unsafe { nil }
	// SkColor 0xAARRGGBB, subpixel positioning and linear metrics (flags 1|2).
	drawn, pixels := draw_tile(ct_font, 2, 3, 0xff143cc8)
	assert drawn == 1
	mut surface := canvas.new_raster_surface(
		width:  40
		height: 24
		props:  canvas.SurfaceProps{
			text_contrast: 0
			text_gamma:    0
		}
	)!
	surface.clear(background)
	font := canvas.Font{
		typeface:       canvas.Typeface.from_ct_font(ct_font)!
		size:           16
		edging:         .subpixel_antialias
		hinting:        .slight
		subpixel:       true
		linear_metrics: true
	}
	points := [canvas.Point{0, 0}, canvas.Point{10.3, 0}, canvas.Point{21.7, 0}]
	paint := canvas.Paint.rgba8(0x14, 0x3c, 0xc8, 0xff)
	surface.draw_glyphs(font, run_glyphs, points, canvas.Point{3.25, 18}, paint)!
	assert surface.pixels.any(it != background)
	for y in 0 .. 24 {
		assert pixels[y * 48..y * 48 + 40] == surface.pixels[y * 40..y * 40 + 40]
		assert pixels[y * 48 + 40..y * 48 + 48].all(it == padding)
	}
	// The bridge's CTFont is wrapped once and reused.
	again, _ := draw_tile(ct_font, 2, 3, 0xff000000)
	assert again == 1
	assert typefaces.fonts.filter(it == ct_font).len == 1
	C.CFRelease(ct_font)
}

fn test_unsupported_glyph_runs_leave_pixels_untouched() {
	ct_font := arial_ct_font()
	unknown_edging, first := draw_tile(ct_font, 3, 3, 0xff000000)
	assert unknown_edging == 0
	assert first == tile()
	synthetic_bold, second := draw_tile(ct_font, 2, 3 | 4, 0xff000000)
	assert synthetic_bold == 0
	assert second == tile()
	missing_font, third := draw_tile(unsafe { nil }, 2, 3, 0xff000000)
	assert missing_font == 0
	assert third == tile()
	C.CFRelease(ct_font)
}
