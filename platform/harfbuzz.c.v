// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

import os

#pkgconfig harfbuzz
#include <hb.h>
#include <hb-ot.h>

struct C.hb_glyph_info_t {
	codepoint u32
	mask      u32
	cluster   u32
	var1      u32
	var2      u32
}

struct C.hb_glyph_position_t {
	x_advance int
	y_advance int
	x_offset  int
	y_offset  int
	var_      u32
}

fn C.hb_blob_create_from_file_or_fail(file_name &char) voidptr
fn C.hb_blob_destroy(blob voidptr)
fn C.hb_face_create(blob voidptr, index u32) voidptr
fn C.hb_face_destroy(face voidptr)
fn C.hb_font_create(face voidptr) voidptr
fn C.hb_font_destroy(font voidptr)
fn C.hb_ot_font_set_funcs(font voidptr)
fn C.hb_font_set_scale(font voidptr, x_scale int, y_scale int)
fn C.hb_font_set_ptem(font voidptr, ptem f32)
fn C.hb_buffer_create() voidptr
fn C.hb_buffer_destroy(buffer voidptr)
fn C.hb_buffer_add_utf8(buffer voidptr, text &char, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_add_utf16(buffer voidptr, text &u16, text_length int, item_offset u32, item_length int)
fn C.hb_buffer_set_direction(buffer voidptr, direction int)
fn C.hb_script_from_string(text &char, length int) u32
fn C.hb_buffer_set_script(buffer voidptr, script u32)
fn C.hb_buffer_guess_segment_properties(buffer voidptr)
fn C.hb_shape(font voidptr, buffer voidptr, features voidptr, feature_count u32)
fn C.hb_buffer_get_glyph_infos(buffer voidptr, length &u32) &C.hb_glyph_info_t
fn C.hb_buffer_get_glyph_positions(buffer voidptr, length &u32) &C.hb_glyph_position_t

const harfbuzz_direction_ltr = 4
const harfbuzz_direction_rtl = 5
const harfbuzz_text_shaping_resolution = f32(64)

__global (
	harfbuzz_layout_test_blob      voidptr
	harfbuzz_layout_test_face      voidptr
	harfbuzz_layout_test_attempted bool
	harfbuzz_bold_blob             voidptr
	harfbuzz_bold_face             voidptr
	harfbuzz_bold_attempted        bool
	harfbuzz_emoji_blob            voidptr
	harfbuzz_emoji_face            voidptr
	harfbuzz_emoji_attempted       bool
)

fn bundled_font_path(file_name string) ?string {
	if source_root := os.getenv_opt('LADYBIRD_SOURCE_ROOT') {
		path := os.join_path(source_root, 'Base', 'res', 'fonts', file_name)
		if os.is_file(path) {
			return path
		}
	}
	repository_root := os.dir(os.dir(@FILE))
	path := os.join_path(repository_root, '..', '3rd', 'ladybird', 'Base', 'res', 'fonts',
		file_name)
	if os.is_file(path) {
		return path
	}
	return none
}

// The native display-list player must use the same fallback face as HarfBuzz:
// retained glyph indices cannot be replayed through an inferred system font.
pub fn emoji_font_path() ?string {
	return bundled_font_path('NotoEmoji.ttf')
}

fn configured_document_font_path() ?string {
	if configured := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT') {
		if os.is_file(configured) {
			return configured
		}
	}
	return bundled_font_path('SerenitySans-Regular.ttf')
}

fn bold_font_path_candidates(regular_path string) []string {
	extension := os.file_ext(regular_path)
	if extension == '' {
		return []
	}
	stem := regular_path[..regular_path.len - extension.len]
	mut candidates := []string{}
	if stem.ends_with('-Regular') {
		candidates << stem[..stem.len - '-Regular'.len] + '-Bold' + extension
	}
	if stem.ends_with(' Regular') {
		candidates << stem[..stem.len - ' Regular'.len] + ' Bold' + extension
	}
	candidates << stem + ' Bold' + extension
	return candidates
}

// Return the concrete face used for document shaping. Gfx::FontDatabase picks
// a real bold face before falling back to synthetic bold; mirror that lookup
// for the file-backed HarfBuzz boundary so glyph IDs and advances are retained
// from the same face that native replay uses.
pub fn document_font_path(weight int) ?string {
	regular_path := configured_document_font_path()?
	if weight < 600 {
		return regular_path
	}
	if configured := os.getenv_opt('LADYBIRD_LAYOUT_TEST_BOLD_FONT') {
		if os.is_file(configured) {
			return configured
		}
	}
	if configured := os.getenv_opt('LADYBIRD_BROWSER_BOLD_FONT') {
		if os.is_file(configured) {
			return configured
		}
	}
	for candidate in bold_font_path_candidates(regular_path) {
		if os.is_file(candidate) {
			return candidate
		}
	}
	return regular_path
}

fn layout_test_harfbuzz_face(weight int) ?voidptr {
	if weight >= 600 {
		if harfbuzz_bold_face != unsafe { nil } {
			return harfbuzz_bold_face
		}
		if harfbuzz_bold_attempted {
			return none
		}
		harfbuzz_bold_attempted = true
		path := document_font_path(weight)?
		blob := C.hb_blob_create_from_file_or_fail(path.str)
		if blob == unsafe { nil } {
			return none
		}
		face := C.hb_face_create(blob, 0)
		if face == unsafe { nil } {
			C.hb_blob_destroy(blob)
			return none
		}
		harfbuzz_bold_blob = blob
		harfbuzz_bold_face = face
		return face
	}
	if harfbuzz_layout_test_face != unsafe { nil } {
		return harfbuzz_layout_test_face
	}
	if harfbuzz_layout_test_attempted {
		return none
	}
	harfbuzz_layout_test_attempted = true
	path := document_font_path(weight)?
	blob := C.hb_blob_create_from_file_or_fail(path.str)
	if blob == unsafe { nil } {
		return none
	}
	face := C.hb_face_create(blob, 0)
	if face == unsafe { nil } {
		C.hb_blob_destroy(blob)
		return none
	}
	harfbuzz_layout_test_blob = blob
	harfbuzz_layout_test_face = face
	return face
}

fn emoji_harfbuzz_face() ?voidptr {
	if harfbuzz_emoji_face != unsafe { nil } {
		return harfbuzz_emoji_face
	}
	if harfbuzz_emoji_attempted {
		return none
	}
	harfbuzz_emoji_attempted = true
	path := bundled_font_path('NotoEmoji.ttf')?
	blob := C.hb_blob_create_from_file_or_fail(path.str)
	if blob == unsafe { nil } {
		return none
	}
	face := C.hb_face_create(blob, 0)
	if face == unsafe { nil } {
		C.hb_blob_destroy(blob)
		return none
	}
	harfbuzz_emoji_blob = blob
	harfbuzz_emoji_face = face
	return face
}

fn is_emoji_code_point(code_point u32) bool {
	return code_point in u32(0x1f000)..u32(0x1fb00) || code_point in u32(0x2600)..u32(0x2800)
}

// FontComputer appends the layout-test Noto Emoji face to every font cascade.
// TextNodeChunks then selects it for an emoji grapheme before calling
// Gfx::shape_text(). This port currently carries one Font per chunk, so make
// the same cascade selection at the platform boundary for emoji-only chunks.
fn text_uses_emoji_fallback(text string) bool {
	mut found_emoji := false
	for character in text.runes() {
		code_point := u32(character)
		if is_emoji_code_point(code_point) {
			found_emoji = true
			continue
		}
		if code_point in [u32(0x200d), u32(0xfe0e), u32(0xfe0f)]
			|| code_point in u32(0x1f3fb)..u32(0x1f400) {
			continue
		}
		return false
	}
	return found_emoji
}

fn utf16_code_units(text string) []u16 {
	mut units := []u16{cap: text.len}
	for character in text.runes() {
		code_point := u32(character)
		if code_point <= 0xffff {
			units << u16(code_point)
		} else {
			value := code_point - 0x10000
			units << u16(0xd800 + (value >> 10))
			units << u16(0xdc00 + (value & 0x3ff))
		}
	}
	return units
}

// Literal Gfx::shape_text() HarfBuzz path. The caller retains the deterministic
// TrueType fallback for standalone builds where the Layout test face is absent.
fn shape_text_with_harfbuzz(initial_x f32, letter_spacing f32, text string, font &Font, text_type GlyphRunTextType) ?&GlyphRun {
	mut face := unsafe { nil }
	uses_emoji := text_uses_emoji_fallback(text)
	if uses_emoji {
		face = emoji_harfbuzz_face()?
	} else {
		face = layout_test_harfbuzz_face(font.weight)?
	}
	hb_font := C.hb_font_create(face)
	if hb_font == unsafe { nil } {
		return none
	}
	C.hb_ot_font_set_funcs(hb_font)
	scale := int(font.point_size * harfbuzz_text_shaping_resolution)
	C.hb_font_set_scale(hb_font, scale, scale)
	C.hb_font_set_ptem(hb_font, font.point_size)
	buffer := C.hb_buffer_create()
	if buffer == unsafe { nil } {
		C.hb_font_destroy(hb_font)
		return none
	}
	mut utf16_units := utf16_code_units(text)
	if text.is_ascii() {
		C.hb_buffer_add_utf8(buffer, text.str, text.len, 0, -1)
	} else if utf16_units.len > 0 {
		C.hb_buffer_add_utf16(buffer, utf16_units.data, utf16_units.len, 0, -1)
	}
	if text.is_ascii() {
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
	for index in 0 .. int(glyph_count) {
		info := unsafe { infos[index] }
		position := unsafe { positions[index] }
		advance := f32(position.x_advance) / harfbuzz_text_shaping_resolution + letter_spacing
		starting_offset := int(info.cluster)
		mut length_in_code_units := utf16_units.len - starting_offset
		for following_index in index + 1 .. int(glyph_count) {
			following_offset := int(unsafe { infos[following_index] }.cluster)
			if following_offset != starting_offset {
				length_in_code_units = following_offset - starting_offset
				break
			}
		}
		glyphs << Glyph{
			code_point:           info.codepoint
			glyph_index:          int(info.codepoint)
			position:             GlyphPosition{
				x: point_x + f32(position.x_offset) / harfbuzz_text_shaping_resolution
				y: f32(position.y_offset) / harfbuzz_text_shaping_resolution
			}
			advance:              advance
			length_in_code_units: length_in_code_units
		}
		point_x += advance
	}
	C.hb_buffer_destroy(buffer)
	C.hb_font_destroy(hb_font)
	return GlyphRun.new_with_face(font, text_type, glyphs, if uses_emoji {
		.emoji
	} else {
		.document
	})
}
