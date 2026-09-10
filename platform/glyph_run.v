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

// Identifies the concrete face whose glyph indices are stored in the run.
// A glyph index is meaningful only for that face, so retained display-list
// playback must not infer this again from the source string.
pub enum GlyphRunFace {
	document
	emoji
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
	glyphs_            []Glyph
	font_              &Font = unsafe { nil }
	text_type_         GlyphRunTextType
	face_              GlyphRunFace
	width_             f32
	space_width        f32
	glyph_indices_     []u16
	glyph_positions_   []f64
	replay_data_dirty_ bool
}

pub fn GlyphRun.new(font &Font, text_type GlyphRunTextType, glyphs []Glyph) &GlyphRun {
	return GlyphRun.new_with_face(font, text_type, glyphs, .document)
}

pub fn GlyphRun.new_with_face(font &Font, text_type GlyphRunTextType, glyphs []Glyph,
	face GlyphRunFace) &GlyphRun {
	mut space_width := f32(font.point_size * 0.5)
	mut width := f32(0)
	mut glyph_indices := []u16{cap: glyphs.len}
	mut glyph_positions := []f64{cap: glyphs.len * 2}
	for glyph in glyphs {
		width += glyph.advance
		if glyph.code_point == u32(` `) {
			space_width = glyph.advance
		}
		glyph_indices << u16(glyph.glyph_index)
		glyph_positions << f64(glyph.position.x)
		glyph_positions << f64(glyph.position.y)
	}
	return &GlyphRun{
		font_:            font
		text_type_:       text_type
		face_:            face
		width_:           width
		glyphs_:          glyphs.clone()
		space_width:      space_width
		glyph_indices_:   glyph_indices
		glyph_positions_: glyph_positions
	}
}

pub fn (run &GlyphRun) font() &Font {
	return run.font_
}

pub fn (run &GlyphRun) text_type() GlyphRunTextType {
	return run.text_type_
}

pub fn (run &GlyphRun) face() GlyphRunFace {
	return run.face_
}

pub fn (run &GlyphRun) glyphs() []Glyph {
	return run.glyphs_
}

// Layout merges adjacent text chunks by mutating the destination GlyphRun.
// Intrinsic sizing can nevertheless reuse the considerably more expensive
// HarfBuzz result as long as every consumer gets independent mutable storage.
pub fn (run &GlyphRun) clone_for_layout() &GlyphRun {
	return &GlyphRun{
		glyphs_:            run.glyphs_.clone()
		font_:              run.font_
		text_type_:         run.text_type_
		face_:              run.face_
		width_:             run.width_
		space_width:        run.space_width
		glyph_indices_:     run.glyph_indices_.clone()
		glyph_positions_:   run.glyph_positions_.clone()
		replay_data_dirty_: run.replay_data_dirty_
	}
}

// Packed retained playback data. CGPoint uses two f64 values on macOS, so the
// position buffer can cross the V/CoreGraphics boundary without rebuilding it
// on every paint.
pub fn (run &GlyphRun) glyph_indices() []u16 {
	return run.glyph_indices_
}

pub fn (run &GlyphRun) glyph_positions() []f64 {
	return run.glyph_positions_
}

// LineBoxFragment merges and repositions shaped chunks after GlyphRun
// construction. DisplayListRecorder calls this only once the line is complete,
// mirroring Gfx::GlyphRun::ensure_text_blob() rather than caching a partial run
// at HarfBuzz return time.
pub fn (mut run GlyphRun) refresh_replay_data() {
	if !run.replay_data_dirty_ {
		return
	}
	run.glyph_indices_.clear()
	run.glyph_positions_.clear()
	for glyph in run.glyphs_ {
		run.glyph_indices_ << u16(glyph.glyph_index)
		run.glyph_positions_ << f64(glyph.position.x)
		run.glyph_positions_ << f64(glyph.position.y)
	}
	run.replay_data_dirty_ = false
}

pub fn (mut run GlyphRun) invalidate_replay_data() {
	run.replay_data_dirty_ = true
}

// Gfx::GlyphRun::slice(). Positions intentionally remain in the coordinate
// system of the original run; text-shadow paints the sliced glyphs at the same
// baseline instead of reshaping or shifting the selected substring.
pub fn (run &GlyphRun) slice(start int, length int) &GlyphRun {
	return GlyphRun.new_with_face(run.font_, run.text_type_, run.glyphs_[start..start + length], run.face_)
}

pub fn (mut run GlyphRun) mutable_glyphs() []Glyph {
	run.invalidate_replay_data()
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
	return run.width_
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
