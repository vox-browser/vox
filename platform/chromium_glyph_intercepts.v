@[has_globals]
module platform

import math

type SkiaGlyphIntercepts = fn (&char, i32, f32, i32, i32, i32, &u16, &f32, i32, f32, f32, &f32, i32) i32
type SkiaInterceptRegisterFace = fn (&char, &char, &char, &u32, &f32, i32) i32

struct ChromiumGlyphInterceptLookup {
mut:
	attempted bool
	intercepts voidptr
	register_face voidptr
}

__global chromium_glyph_intercept_lookup = ChromiumGlyphInterceptLookup{}

fn chromium_glyph_intercept_functions() {
	$if macos {
		if !chromium_glyph_intercept_lookup.attempted {
			chromium_glyph_intercept_lookup.attempted = true
			chromium_glyph_intercept_lookup.intercepts = C.dlsym(unsafe { voidptr(int(-2)) },
				c'ladybird_v_skia_glyph_intercepts')
			chromium_glyph_intercept_lookup.register_face = C.dlsym(unsafe { voidptr(int(-2)) },
				c'ladybird_v_skia_register_system_face')
		}
	}
}

// The raw TrueType contour reader does not instantiate variation coordinates.
// Use the same registered face as native glyph replay for those Chromium runs.
// A missing native bridge retains the portable contour implementation.
fn chromium_variable_glyph_intercepts(run &GlyphRun, scale f32, top f32, bottom f32) ?[]f32 {
	font := run.font_
	if font == unsafe { nil } || font.font_rendering_policy != .chromium
		|| font.variations().len == 0 || run.glyphs_.len > 32768 {
		return none
	}
	size := font.point_size * scale
	for value in [size, top, bottom] {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	if size <= 0 || top > bottom { return none }
	chromium_glyph_intercept_functions()
	lookup := chromium_glyph_intercept_lookup
	if lookup.intercepts == unsafe { nil } || lookup.register_face == unsafe { nil } {
		return none
	}
	face := font.replay_face() or { return none }
	key := face.replay_key()
	tags := face.variations.map(it.tag)
	values := face.variations.map(it.value)
	register := unsafe { SkiaInterceptRegisterFace(lookup.register_face) }
	if register(&char(key.str), &char(face.path.str), &char(face.postscript_name.str),
		tags.data, values.data, i32(tags.len)) == 0 { return none }
	mut glyphs := []u16{cap: run.glyphs_.len}
	mut positions := []f32{cap: run.glyphs_.len * 2}
	for glyph in run.glyphs_ {
		if !glyph.should_paint { continue }
		if glyph.glyph_index < 0 || glyph.glyph_index > 0xffff { return none }
		x := glyph.position.x * scale
		y := glyph.position.y * scale
		if math.is_nan(x) || math.is_nan(y) || math.is_inf(x, 0) || math.is_inf(y, 0) { return none }
		glyphs << u16(glyph.glyph_index)
		positions << [x, y]
	}
	if glyphs.len == 0 { return []f32{} }
	mut intervals := []f32{len: glyphs.len * 2}
	measure := unsafe { SkiaGlyphIntercepts(lookup.intercepts) }
	count := int(measure(&char(key.str), i32(face.face_index), size, i32(font.weight),
		i32(font.italic), i32(font.font_synthesis_disabled), glyphs.data, positions.data,
		i32(glyphs.len), top, bottom, intervals.data, i32(intervals.len)))
	if count < 0 || count > intervals.len || count % 2 != 0 { return none }
	for value in intervals[..count] {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	return intervals[..count]
}
