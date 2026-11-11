// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module platform

import math
import os
import time

// Canonical producer ownership reference, with the HarfBuzz y-axis conversion
// corrected alongside the current producer (Ladybird 3c3783ccd1f0).
// Baseline Git revision: 77e2a22e276ea51477663a5f9fa22b1b38743556.
fn cold_legacy_hb(initial_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ?ShapedText {
	mut face := unsafe { nil }
	uses_emoji := text_uses_emoji_fallback(text)
	if uses_emoji {
		face = emoji_harfbuzz_face()?
	} else {
		face = document_harfbuzz_face(font)?
	}
	hb_font := scaled_harfbuzz_font(face, font.point_size, font.shaping_resolution(),
		font.variations())?
	buffer := C.hb_buffer_create()
	if buffer == unsafe { nil } {
		return none
	}
	is_ascii := text.is_ascii()
	mut utf16_units := []u16{}
	text_length_in_code_units := if is_ascii {
		text.len
	} else {
		utf16_units = utf16_code_units(text)
		utf16_units.len
	}
	if is_ascii {
		C.hb_buffer_add_utf8(buffer, text.str, text.len, 0, -1)
	} else if utf16_units.len > 0 {
		C.hb_buffer_add_utf16(buffer, utf16_units.data, utf16_units.len, 0, -1)
	}
	if is_ascii {
		C.hb_buffer_set_script(buffer, C.hb_script_from_string(c'Latn', 4))
		C.hb_buffer_set_direction(buffer, harfbuzz_direction_ltr)
	} else {
		if text_type == .ltr {
			C.hb_buffer_set_direction(buffer, harfbuzz_direction_ltr)
		} else if text_type == .rtl {
			C.hb_buffer_set_direction(buffer, harfbuzz_direction_rtl)
		}
		C.hb_buffer_guess_segment_properties(buffer)
	}
	C.hb_shape(hb_font, buffer, unsafe { nil }, 0)
	mut glyph_count := u32(0)
	infos := C.hb_buffer_get_glyph_infos(buffer, &glyph_count)
	positions := C.hb_buffer_get_glyph_positions(buffer, &glyph_count)
	mut glyphs := []Glyph{cap: int(glyph_count)}
	mut point_x := initial_x
	trailing_length := trailing_whitespace_length(text)
	first_trailing_offset := text_length_in_code_units - trailing_length
	mut trailing_advance := f32(0)
	for index in 0 .. int(glyph_count) {
		info := unsafe { infos[index] }
		position := unsafe { positions[index] }
		starting_offset := int(info.cluster)
		code_point := code_point_at_utf16_offset(text, utf16_units, is_ascii, starting_offset)
		is_default_ignorable := code_point_is_default_ignorable(code_point)
		should_paint := !font.is_invisible && !is_default_ignorable
		mut advance := f32(0)
		if !is_default_ignorable {
			advance = f32(position.x_advance) / font.shaping_resolution() + letter_spacing
			if is_word_separator(code_point) {
				advance += word_spacing
			}
		}
		mut length_in_code_units := text_length_in_code_units - starting_offset
		for following_index in index + 1 .. int(glyph_count) {
			following_offset := int(unsafe { infos[following_index] }.cluster)
			if following_offset != starting_offset {
				length_in_code_units = following_offset - starting_offset
				break
			}
		}
		glyphs << Glyph{
			code_point:           code_point
			glyph_index:          int(info.codepoint)
			position:             GlyphPosition{
				x: point_x + f32(position.x_offset) / font.shaping_resolution()
				y: f32(-i64(position.y_offset)) / font.shaping_resolution()
			}
			advance:              advance
			offset_x:             f32(position.x_offset) / font.shaping_resolution()
			length_in_code_units: length_in_code_units
			should_paint:         should_paint
		}
		if !is_default_ignorable && starting_offset >= first_trailing_offset {
			trailing_advance += advance
		}
		if !is_default_ignorable {
			point_x += advance
		}
	}
	C.hb_buffer_destroy(buffer)
	return ShapedText{
		glyph_run:           GlyphRun.new_with_face(font, text_type, glyphs, if uses_emoji {
			.emoji
		} else {
			.document
		})
		trailing_whitespace: TrailingWhitespace{
			length_in_code_units: trailing_length
			advance:              trailing_advance
		}
	}
}

fn cold_legacy_uncached(initial_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ShapedText {
	if shaped := shape_text_with_harfbuzz(initial_x, letter_spacing, word_spacing, text, font,
		text_type)
	{
		return shaped
	}
	mut glyphs := []Glyph{}
	mut x := initial_x
	text_length_in_code_units := utf16_units_for_shaping(text).len
	trailing_length := trailing_whitespace_length(text)
	first_trailing_offset := text_length_in_code_units - trailing_length
	mut trailing_advance := f32(0)
	mut code_unit_offset := 0
	font.reset_kerning()
	for character in text.runes() {
		code_point := u32(character)
		base_advance, glyph_index := font.glyph_metrics(code_point)
		is_default_ignorable := code_point_is_default_ignorable(code_point)
		should_paint := !font.is_invisible && !is_default_ignorable
		// HarfBuzz returns positions in the 26.6 scale selected by
		// Gfx::Font::harfbuzz_font(). Quantize each shaped value separately,
		// before accumulating it, just as TextLayout.cpp does when dividing the
		// integer hb_glyph_position_t fields by text_shaping_resolution.
		mut advance := f32(0)
		if !is_default_ignorable {
			x += f32(math.round(f64(font.kerning_for_glyph(glyph_index)) * 64.0) / 64.0)
			advance = f32(math.round(f64(base_advance) * 64.0) / 64.0) + letter_spacing
			if is_word_separator(code_point) {
				advance += word_spacing
			}
		}
		glyphs << Glyph{
			code_point:           code_point
			glyph_index:          glyph_index
			position:             GlyphPosition{
				x: x
			}
			advance:              advance
			length_in_code_units: if code_point > 0xffff { 2 } else { 1 }
			should_paint:         should_paint
		}
		if code_unit_offset >= first_trailing_offset {
			trailing_advance += advance
		}
		x += advance
		code_unit_offset += if code_point > 0xffff { 2 } else { 1 }
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
	return ShapedText{
		glyph_run:           GlyphRun.new(font, text_type, glyphs)
		trailing_whitespace: TrailingWhitespace{
			length_in_code_units: trailing_length
			advance:              trailing_advance
		}
	}
}

// Preload the translated face, then remove its file before the first HB lookup.
// Font owns the decoded face; HB must fail its independent file open.
fn cold_fallback_font(invisible bool) &Font {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(),
		'vox-cold-fallback-${os.getpid()}-${time.sys_mono_now()}.ttf')
	os.cp(source, path) or { panic(err) }
	defer { os.rm(path) or {} }
	font := &Font{
		family:       'SerenitySans'
		point_size:   13.25
		source_path:  path
		is_invisible: invisible
	}
	_ = font_face(font) or { panic('fixture face failed to decode') }
	assert font.decoded_face_ != unsafe { nil }
	os.rm(path) or { panic(err) }
	assert !os.is_file(path)
	return font
}

fn cold_fixture_font(invisible bool) &Font {
	return &Font{
		family:       'SerenitySans'
		point_size:   13.25
		source_path:  bundled_font_path('SerenitySans-Regular.ttf') or {
			panic('missing test font')
		}
		is_invisible: invisible
	}
}

fn cold_assert_equal(actual ShapedText, expected ShapedText) {
	a := actual.glyph_run
	b := expected.glyph_run
	assert a.glyphs_ == b.glyphs_
	assert a.glyph_indices_ == b.glyph_indices_
	assert a.glyph_positions_ == b.glyph_positions_
	assert a.bounding_box_ == b.bounding_box_
	assert math.f32_bits(a.width_) == math.f32_bits(b.width_)
	assert math.f32_bits(a.space_width) == math.f32_bits(b.space_width)
	assert a.font_ == b.font_
	assert a.face_ == b.face_
	assert a.text_type_ == b.text_type_
	assert a.replay_data_dirty_ == b.replay_data_dirty_
	assert actual.trailing_whitespace.length_in_code_units == expected.trailing_whitespace.length_in_code_units
	assert math.f32_bits(actual.trailing_whitespace.advance) == math.f32_bits(expected.trailing_whitespace.advance)
	for i, g in a.glyphs_ {
		assert math.f32_bits(g.position.x) == math.f32_bits(b.glyphs_[i].position.x)
		assert math.f32_bits(g.position.y) == math.f32_bits(b.glyphs_[i].position.y)
		assert math.f32_bits(g.advance) == math.f32_bits(b.glyphs_[i].advance)
		assert g.length_in_code_units == b.glyphs_[i].length_in_code_units
	}
}

fn cold_inputs() []string {
	return ['', 'a', 'office ffi AV', 'Привет, мир! сыр⁠⁠10 ',
		'مرحبا بالعالم', 'а́б क्‍ष', '👩‍👩‍👧‍👦', 'a😀b',
		'a⁠‍️b', 'x\t \r\n', [u8(0xff), 0xcc, 0x81, 0x20].bytestr(),
		[u8(0xed), 0xa0, 0x80, 0x61].bytestr()]
}

fn test_cold_native_glyph_transfer_matches_original_harfbuzz_producer() {
	for invisible in [false, true] {
		font := cold_fixture_font(invisible)
		for text in cold_inputs() {
			for kind in [GlyphRunTextType.common, .context_dependent, .end_padding, .ltr, .rtl] {
				for x in [f32(0), 17.25, -9.5, math.f32_from_bits(u32(0x80000000))] {
					expected := cold_legacy_hb(x, 0.25, 1.5, text, font, kind) or {
						panic('legacy HB producer not reached')
					}
					actual := shape_text_with_harfbuzz(x, 0.25, 1.5, text, font, kind) or {
						panic('native HB producer not reached')
					}
					cold_assert_equal(actual, expected)
				}
			}
		}
	}
}

fn test_cold_synthetic_glyph_transfer_matches_original_fallback_producer() {
	for invisible in [false, true] {
		font := cold_fallback_font(invisible)
		for raw_text in cold_inputs() {
			text := if text_uses_emoji_fallback(raw_text) { 'a' + raw_text } else { raw_text }
			if _ := shape_text_with_harfbuzz(0, 0, 0, text, font, .common) {
				panic('fallback fixture did not suppress HB')
			}
			for kind in [GlyphRunTextType.common, .context_dependent, .end_padding, .ltr, .rtl] {
				for x in [f32(0), 17.25, -9.5, math.f32_from_bits(u32(0x80000000))] {
					cold_assert_equal(shape_text_uncached(x, 0.25, 1.5, text, font, kind), cold_legacy_uncached(x,
						0.25, 1.5, text, font, kind))
				}
			}
		}
	}
}

fn cold_returned_producer(font &Font, native bool) ShapedText {
	if native {
		return shape_text_with_harfbuzz(17.25, 0.25, 1.5, 'office Привет a😀b ⁠ \t ',
			font, .rtl) or { panic('HB producer not reached') }
	}
	return shape_text_uncached(17.25, 0.25, 1.5, 'office Привет a😀b ⁠ \t ', font, .rtl)
}

fn cold_assert_retention(native bool) {
	font := if native { cold_fixture_font(false) } else { cold_fallback_font(false) }
	first := cold_returned_producer(font, native)
	second := cold_returned_producer(font, native)
	saved_glyphs := second.glyph_run.glyphs_.clone()
	saved_indices := second.glyph_run.glyph_indices_.clone()
	saved_positions := second.glyph_run.glyph_positions_.clone()
	saved_bounds := second.glyph_run.bounding_box_
	churn_font := cold_fixture_font(false)
	assert first.glyph_run.glyphs_.len > 0
	assert first.glyph_run.glyphs_.data != second.glyph_run.glyphs_.data
	assert first.glyph_run.glyph_indices_.data != second.glyph_run.glyph_indices_.data
	assert first.glyph_run.glyph_positions_.data != second.glyph_run.glyph_positions_.data
	for _ in 0 .. 3 {
		for text in cold_inputs() {
			_ = shape_text_with_harfbuzz(0, 0, 0, text, churn_font, .common) or {
				panic('HB churn producer not reached')
			}
		}
		gc_collect()
		assert second.glyph_run.glyphs_ == saved_glyphs
		assert second.glyph_run.glyph_indices_ == saved_indices
		assert second.glyph_run.glyph_positions_ == saved_positions
		assert second.glyph_run.bounding_box_ == saved_bounds
	}
	mut changed := first.glyph_run
	changed.glyphs_[0].position.x = 999
	changed.glyphs_[0].advance = 999
	changed.glyph_indices_[0] = 65535
	changed.glyph_positions_[0] = 999
	gc_collect()
	cold_assert_equal(second, cold_returned_producer(font, native))
}

fn test_cold_native_glyph_results_survive_producer_return_gc_and_mutation() {
	cold_assert_retention(true)
}

fn test_cold_synthetic_glyph_results_survive_producer_return_gc_and_mutation() {
	cold_assert_retention(false)
}
