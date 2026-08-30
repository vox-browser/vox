// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

import math

// The data portion of Gfx::GlyphRun used by Layout::LineBoxFragment. Font
// shaping remains a host-font-plugin responsibility, but Layout must retain
// shaped glyph positions and bidi run type exactly instead of reducing text to
// an estimated rectangle.
pub enum GlyphRunTextType {
	common
	context_dependent
	end_padding
	ltr
	rtl
}

pub struct GlyphPosition {
pub mut:
	x f32
	y f32
}

pub fn (mut position GlyphPosition) translate_by(x f32, y f32) {
	position.x += x
	position.y += y
}

pub struct Glyph {
pub mut:
	code_point           u32
	glyph_index          int
	position             GlyphPosition
	advance              f32
	length_in_code_units int = 1
}

@[heap]
pub struct GlyphRun {
pub mut:
	glyphs_     []Glyph
	font_       &Font = unsafe { nil }
	text_type_  GlyphRunTextType
	space_width f32
}

pub fn GlyphRun.new(font &Font, text_type GlyphRunTextType, glyphs []Glyph) &GlyphRun {
	mut space_width := f32(font.point_size * 0.5)
	for glyph in glyphs {
		if glyph.code_point == u32(` `) {
			space_width = glyph.advance
			break
		}
	}
	return &GlyphRun{
		font_:       font
		text_type_:  text_type
		glyphs_:     glyphs.clone()
		space_width: space_width
	}
}

pub fn (run &GlyphRun) font() &Font {
	return run.font_
}

pub fn (run &GlyphRun) text_type() GlyphRunTextType {
	return run.text_type_
}

pub fn (run &GlyphRun) glyphs() []Glyph {
	return run.glyphs_
}

pub fn (mut run GlyphRun) mutable_glyphs() []Glyph {
	return run.glyphs_
}

pub fn (run &GlyphRun) glyph_width(code_unit u16) f32 {
	for glyph in run.glyphs_ {
		if glyph.code_point == u32(code_unit) {
			return glyph.advance
		}
	}
	return run.space_width
}

pub fn (run &GlyphRun) width() f32 {
	mut width := f32(0)
	for glyph in run.glyphs_ {
		candidate := glyph.position.x + glyph.advance
		if candidate > width {
			width = candidate
		}
	}
	return width
}

// Gfx::shape_text()'s layout-facing contract. Native HarfBuzz/CoreText
// shaping belongs behind the platform font provider; this deterministic
// fallback preserves glyph positions, UTF-16 lengths, letter spacing and run
// direction so Layout consumes the same shaped-run representation.
pub fn shape_text(initial_x f32, letter_spacing f32, text string, font &Font, text_type GlyphRunTextType) &GlyphRun {
	if run := shape_text_with_harfbuzz(initial_x, letter_spacing, text, font, text_type) {
		return run
	}
	mut glyphs := []Glyph{}
	mut x := initial_x
	font.reset_kerning()
	for character in text.runes() {
		code_point := u32(character)
		base_advance, glyph_index := font.glyph_metrics(code_point)
		// HarfBuzz returns positions in the 26.6 scale selected by
		// Gfx::Font::harfbuzz_font(). Quantize each shaped value separately,
		// before accumulating it, just as TextLayout.cpp does when dividing the
		// integer hb_glyph_position_t fields by text_shaping_resolution.
		x += f32(math.round(f64(font.kerning_for_glyph(glyph_index)) * 64.0) / 64.0)
		advance := f32(math.round(f64(base_advance) * 64.0) / 64.0) + letter_spacing
		glyphs << Glyph{
			code_point:           code_point
			glyph_index:          glyph_index
			position:             GlyphPosition{
				x: x
			}
			advance:              advance
			length_in_code_units: if code_point > 0xffff { 2 } else { 1 }
		}
		x += advance
	}
	if text_type == .rtl {
		width := x - initial_x
		for index in 0 .. glyphs.len {
			glyphs[index].position.x = initial_x + width - (glyphs[index].position.x - initial_x) -
				glyphs[index].advance
		}
	}
	// Avoid leaking negative zero through the fixed-point conversion used by
	// layout geometry.
	if math.abs(x) < f32(0.000001) {
		x = 0
	}
	return GlyphRun.new(font, text_type, glyphs)
}
