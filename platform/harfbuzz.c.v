// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

import math
import os

#pkgconfig harfbuzz

#flag darwin -licucore

#flag linux -licuuc

#include <hb.h>

#include <hb-ot.h>

#include <unicode/uchar.h>

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

struct HarfBuzzScaledFont {
	face       voidptr
	scale      int
	point_size f32
	font       voidptr
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

fn C.hb_font_get_nominal_glyph(font voidptr, unicode u32, glyph &u32) int

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

fn C.u_hasBinaryProperty(code_point i32, property int) int

const harfbuzz_direction_ltr = 4
const harfbuzz_direction_rtl = 5
const harfbuzz_text_shaping_resolution = f32(64)
const icu_default_ignorable_code_point_property = 5

__global (
	harfbuzz_document_blobs     = map[string]voidptr{}
	harfbuzz_document_faces     = map[string]voidptr{}
	harfbuzz_document_attempted = map[string]bool{}
	harfbuzz_family_paths       = map[string]string{}
	harfbuzz_family_attempted   = map[string]bool{}
	harfbuzz_scaled_fonts       = []HarfBuzzScaledFont{}
	harfbuzz_emoji_blob         voidptr
	harfbuzz_emoji_face         voidptr
	harfbuzz_emoji_attempted    bool
)

fn bundled_font_path(file_name string) ?string {
	if source_root := os.getenv_opt('LADYBIRD_SOURCE_ROOT') {
		path := os.join_path(source_root, 'Base', 'res', 'fonts', file_name)
		if os.is_file(path) {
			return path
		}
	}
	repository_root := os.dir(os.dir(@FILE))
	path := os.join_path(repository_root, '..', '3rd', 'ladybird', 'Base', 'res', 'fonts', file_name)
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
	if configured := os.getenv_opt('LADYBIRD_BROWSER_FONT') {
		if os.is_file(configured) {
			return configured
		}
	}
	if configured := os.getenv_opt('LADYBIRD_BROWSER_DEFAULT_FONT') {
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
	return font_path_for_family('Default', weight)
}

// Resolve the exact file retained by a CSS @font-face before consulting the
// installed family cascade.
pub fn (font &Font) font_path() ?string {
	// Font inputs are immutable. Retain the selected face path for this font
	// handle instead of checking its file for every glyph and replay bound.
	if font.resolved_path_ != '' {
		return font.resolved_path_
	}
	path := if font.source_path != '' && os.is_file(font.source_path) {
		font.source_path
	} else {
		font_path_for_family(font.family, font.weight)?
	}
	// A missing explicit source may still appear later. Do not pin the
	// temporary system fallback selected while that source is unavailable.
	if font.source_path == '' || path == font.source_path {
		mut mutable_font := unsafe { &Font(font) }
		mutable_font.resolved_path_ = path
	}
	return path
}

// CSS weight selects the regular or bold member of the macOS collections used
// by the pages under test. Standalone and downloaded faces always use index 0.
pub fn (font &Font) face_index() int {
	if font.source_path != '' {
		return 0
	}
	$if macos {
		if font.family.to_lower() in ['lucida grande', 'lucida sans unicode', 'lucida sans',
			'helvetica neue', 'gill sans', 'gill sans std'] {
			return if font.weight >= 600 { 1 } else { 0 }
		}
	}
	return 0
}

// Resolve the concrete face selected for a CSS family. Layout metrics,
// HarfBuzz shaping, and native replay all use this path, so retained glyph IDs
// can never be interpreted through a different typeface.
pub fn font_path_for_family(family string, weight int) ?string {
	cache_key := '${family.to_lower()}|${weight}'
	if path := harfbuzz_family_paths[cache_key] {
		return path
	}
	if harfbuzz_family_attempted[cache_key] {
		return none
	}
	harfbuzz_family_attempted[cache_key] = true
	path := resolve_font_path_for_family(family, weight) or { return none }
	harfbuzz_family_paths[cache_key] = path
	return path
}

fn resolve_font_path_for_family(family string, weight int) ?string {
	lower_family := family.to_lower()
	if lower_family == 'noto emoji' {
		return bundled_font_path('NotoEmoji.ttf')
	}
	if configured := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT') {
		if os.is_file(configured) {
			if weight >= 600 {
				if bold := os.getenv_opt('LADYBIRD_LAYOUT_TEST_BOLD_FONT') {
					if os.is_file(bold) {
						return bold
					}
				}
				for candidate in bold_font_path_candidates(configured) {
					if os.is_file(candidate) {
						return candidate
					}
				}
			}
			return configured
		}
	}
	if configured := os.getenv_opt('LADYBIRD_BROWSER_FONT') {
		if os.is_file(configured) {
			if weight >= 600 {
				if bold := os.getenv_opt('LADYBIRD_BROWSER_BOLD_FONT') {
					if os.is_file(bold) {
						return bold
					}
				}
				for candidate in bold_font_path_candidates(configured) {
					if os.is_file(candidate) {
						return candidate
					}
				}
			}
			return configured
		}
	}
	$if macos {
		regular_path := match lower_family {
			// Font.face_index() selects the regular or bold collection member.
			'lucida grande', 'lucida sans unicode', 'lucida sans' {
				'/System/Library/Fonts/LucidaGrande.ttc'
			}

			// Browser replay is configured around Arial-compatible metrics. Keep
			// Helvetica on that face as the C++ macOS reference does here.
			'helvetica' { '/System/Library/Fonts/Supplemental/Arial.ttf' }
			'helvetica neue' { '/System/Library/Fonts/HelveticaNeue.ttc' }
			'gill sans', 'gill sans std' { '/System/Library/Fonts/Supplemental/GillSans.ttc' }
			'tahoma' { '/System/Library/Fonts/Supplemental/Tahoma.ttf' }
			'georgia' { '/System/Library/Fonts/Supplemental/Georgia.ttf' }
			'verdana' { '/System/Library/Fonts/Supplemental/Verdana.ttf' }
			'geneva' { '/System/Library/Fonts/Geneva.ttf' }
			'courier', 'courier new', 'monospace', 'uimonospace' {
				'/System/Library/Fonts/Supplemental/Courier New.ttf'
			}
			'times', 'times new roman', 'serif', 'uiserif' {
				'/System/Library/Fonts/Supplemental/Times New Roman.ttf'
			}
			'arial', 'default', 'sansserif', 'uisansserif', 'ui-rounded', 'uirounded' {
				configured_document_font_path()?
			}
			else { '' }
		}
		if regular_path != '' && os.is_file(regular_path) {
			// CoreText's generic serif cascade keeps Times New Roman's regular
			// advances and synthesizes bold. Preserve those advances for Layout;
			// the Skia replay bridge applies emboldening when the face itself is
			// not bold.
			if weight >= 600 && lower_family !in ['serif', 'uiserif'] {
				for candidate in bold_font_path_candidates(regular_path) {
					if os.is_file(candidate) {
						return candidate
					}
				}
			}
			return regular_path
		}
	}
	$if linux {
		family_name := match lower_family {
			'default', 'uisansserif', 'ui-sans-serif', 'sansserif' { 'sans-serif' }
			'uiserif', 'ui-serif' { 'serif' }
			'uimonospace', 'ui-monospace' { 'monospace' }
			else { family }
		}
		return linux_font_path(family_name, weight, false)
	}
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

fn scaled_harfbuzz_font(face voidptr, point_size f32) ?voidptr {
	scale := scale_for_harfbuzz(point_size)
	for cached in harfbuzz_scaled_fonts {
		if cached.face == face && cached.scale == scale && cached.point_size == point_size {
			return cached.font
		}
	}
	font := C.hb_font_create(face)
	if font == unsafe { nil } {
		return none
	}
	C.hb_ot_font_set_funcs(font)
	C.hb_font_set_scale(font, scale, scale)
	C.hb_font_set_ptem(font, point_size)
	harfbuzz_scaled_fonts << HarfBuzzScaledFont{
		face: face
		scale: scale
		point_size: point_size
		font: font
	}
	return font
}

fn scale_for_harfbuzz(point_size f32) int {
	scaled_point_size := f64(point_size) * f64(harfbuzz_text_shaping_resolution)
	if math.is_nan(scaled_point_size) {
		return 0
	}
	if scaled_point_size >= f64(2147483647) {
		return 2147483647
	}
	if scaled_point_size <= f64(-2147483648) {
		return -2147483648
	}
	return int(scaled_point_size)
}

fn document_harfbuzz_face(font &Font) ?voidptr {
	path := font.font_path()?
	face_index := font.face_index()
	cache_key := '${path}|${face_index}'
	if face := harfbuzz_document_faces[cache_key] {
		return face
	}
	if harfbuzz_document_attempted[cache_key] {
		return none
	}
	harfbuzz_document_attempted[cache_key] = true
	blob := C.hb_blob_create_from_file_or_fail(path.str)
	if blob == unsafe { nil } {
		return none
	}
	face := C.hb_face_create(blob, u32(face_index))
	if face == unsafe { nil } {
		C.hb_blob_destroy(blob)
		return none
	}
	harfbuzz_document_blobs[cache_key] = blob
	harfbuzz_document_faces[cache_key] = face
	return face
}

// x.ttf's cmap reader currently handles only formats 0 and 4. Use HarfBuzz as
// the authoritative glyph-coverage probe as Gfx::Font does upstream, including
// for BMP characters stored only in a format-12 cmap.
fn harfbuzz_font_contains_glyph(font &Font, code_point u32) ?bool {
	face := document_harfbuzz_face(font)?
	hb_font := scaled_harfbuzz_font(face, font.point_size)?
	mut glyph := u32(0)
	return C.hb_font_get_nominal_glyph(hb_font, code_point, &glyph) != 0 && glyph != 0
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
	return code_point in u32(0x1f000) .. u32(0x1fb00) || code_point in u32(0x2600) .. u32(0x2800)
}

// FontComputer appends the layout-test Noto Emoji face to every font cascade.
// TextNodeChunks then selects it for an emoji grapheme before calling
// Gfx::shape_text(). This port currently carries one Font per chunk, so make
// the same cascade selection at the platform boundary for emoji-only chunks.
fn text_uses_emoji_fallback(text string) bool {
	if text.is_ascii() {
		return false
	}
	mut found_emoji := false
	for character in text.runes() {
		code_point := u32(character)
		if is_emoji_code_point(code_point) {
			found_emoji = true
			continue
		}
		if code_point in [u32(0x200d), u32(0xfe0e), u32(0xfe0f)]
			|| code_point in u32(0x1f3fb) .. u32(0x1f400) {
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
fn code_point_at_utf16_offset(text string, utf16_units []u16, is_ascii bool, offset int) u32 {
	if offset < 0 {
		return 0
	}
	if is_ascii {
		if offset >= text.len {
			return 0
		}
		return u32(text[offset])
	}
	if offset >= utf16_units.len {
		return 0
	}
	first := u32(utf16_units[offset])
	if first !in u32(0xd800) .. u32(0xdc00) || offset + 1 >= utf16_units.len {
		return first
	}
	second := u32(utf16_units[offset + 1])
	if second !in u32(0xdc00) .. u32(0xe000) {
		return first
	}
	return 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00
}

fn code_point_is_default_ignorable(code_point u32) bool {
	return C.u_hasBinaryProperty(i32(code_point), icu_default_ignorable_code_point_property) != 0
}

fn shape_text_with_harfbuzz(initial_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ?ShapedText {
	mut face := unsafe { nil }
	uses_emoji := text_uses_emoji_fallback(text)
	if uses_emoji {
		face = emoji_harfbuzz_face()?
	} else {
		face = document_harfbuzz_face(font)?
	}
	hb_font := scaled_harfbuzz_font(face, font.point_size)?
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
			advance = f32(position.x_advance) / harfbuzz_text_shaping_resolution + letter_spacing
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
			code_point: code_point
			glyph_index: int(info.codepoint)
			position: GlyphPosition{
				x: point_x + f32(position.x_offset) / harfbuzz_text_shaping_resolution
				y: f32(position.y_offset) / harfbuzz_text_shaping_resolution
			}
			advance: advance
			length_in_code_units: length_in_code_units
			should_paint: should_paint
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
		glyph_run: GlyphRun.new_with_face(font, text_type, glyphs, if uses_emoji {
			.emoji
		} else {
			.document
		})
		trailing_whitespace: TrailingWhitespace{
			length_in_code_units: trailing_length
			advance: trailing_advance
		}
	}
}
