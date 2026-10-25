module platform

import math

// Blink's layout_text_control::{HasValidAvgCharWidth,GetAvgCharWidth}.
// Some legacy Mac fonts contain unsuitable average metrics; these use the
// unrounded zero advance instead. The CJK heuristic applies to every face.
pub fn (font &Font) form_control_character_widths(coordinate_scale f64) (f32, f32) {
	zero := font.glyph_width(u32(`0`)) / f32(coordinate_scale)
	mut average := f32(0)
	mut maximum := f32(0)
	mut family := font.family
	$if macos {
		// SimpleFontData::PlatformInit uses the 'x' advance and ascent on Mac,
		// because Skia's OS/2 average/maximum metrics are unsuitable there.
		average = font.glyph_width(u32(`x`))
		maximum = font.pixel_metrics().ascent
		if face := font.system_face() {
			family = face.family_name
		}
	} $else {
		if face := font_face(font) {
			scale := font.point_size / f32(face.units_per_em)
			if os2 := font_table_offset(face.buf, 'OS/2') {
				average = f32(font_i16_at(face.buf, os2 + 2) or { 0 }) * scale
			}
		}
		if bounds := font.typeface_bounds() {
			maximum = f32(math.round(f64(bounds.x_max - bounds.x_min) / coordinate_scale) * coordinate_scale)
		}
		if average == 0 {
			average = font.glyph_width(u32(`x`))
		}
	}
	average /= f32(coordinate_scale)
	maximum /= f32(coordinate_scale)
	if average <= 0 || average > zero * 1.7 || family in [
		'American Typewriter',
		'Arial Hebrew',
		'Chalkboard',
		'Cochin',
		'Corsiva Hebrew',
		'Courier',
		'Euphemia UCAS',
		'Geneva',
		'Gill Sans',
		'Hei',
		'Helvetica',
		'Hoefler Text',
		'InaiMathi',
		'Kai',
		'Lucida Grande',
		'Marker Felt',
		'Monaco',
		'Mshtakan',
		'New Peninim MT',
		'Osaka',
		'Raanana',
		'STHeiti',
		'Symbol',
		'Times',
		'Apple Braille',
		'Apple LiGothic',
		'Apple LiSung',
		'Apple Symbols',
		'AppleGothic',
		'AppleMyungjo',
		'#GungSeo',
		'#HeadLineA',
		'#PCMyungjo',
		'#PilGi',
	] {
		return zero, zero
	}
	return f32(math.max(f64(average), math.round(average))), maximum
}
