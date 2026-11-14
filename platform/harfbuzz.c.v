// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

import math
import vunicode
import os

// The HarfBuzz VPM module supplies optimized macOS OpenType/CoreText archives
// without Graphite2; other platforms use their system HarfBuzz. Font selection,
// Unicode handling and glyph-run policy remain in V.
$if macos {
	import harfbuzz as _
} $else {
	#pkgconfig harfbuzz
}

#include <hb.h>

$if !windows {
	#include <dlfcn.h>
}

#include <hb-ot.h>

$if macos {
	#include "harfbuzz_coretext_macos.h"
}

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

struct C.hb_feature_t {
	tag   u32
	value u32
	start u32
	end   u32
}

struct HarfBuzzScaledFont {
mut:
	face             voidptr
	scale            int
	point_size       f32
	ptem             f32
	variations       []FontVariationAxis
	font             voidptr
	coretext_hyphens bool
}

fn C.dlsym(handle voidptr, symbol &char) voidptr

fn C.hb_blob_create_from_file_or_fail(file_name &char) voidptr

fn C.hb_blob_destroy(blob voidptr)

fn C.hb_face_create(blob voidptr, index u32) voidptr

fn C.hb_face_destroy(face voidptr)

fn C.hb_face_reference_blob(face voidptr) voidptr

fn C.hb_blob_get_data(blob voidptr, length &u32) &char

fn C.hb_font_create(face voidptr) voidptr

fn C.hb_font_destroy(font voidptr)

fn C.vox_hb_with_coretext_hyphens(font voidptr) voidptr

fn C.hb_ot_font_set_funcs(font voidptr)

fn C.hb_font_set_scale(font voidptr, x_scale int, y_scale int)

fn C.hb_font_set_ptem(font voidptr, ptem f32)

fn C.hb_font_set_variations(font voidptr, variations voidptr, variations_length u32)

fn C.hb_font_get_nominal_glyph(font voidptr, unicode u32, glyph &u32) int

fn C.hb_font_get_glyph_h_advance(font voidptr, glyph u32) int

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

fn C.hb_glyph_info_get_glyph_flags(info &C.hb_glyph_info_t) u32

fn C.hb_face_reference_table(face voidptr, tag u32) voidptr

fn C.hb_blob_get_length(blob voidptr) u32

const harfbuzz_direction_ltr = 4
const harfbuzz_direction_rtl = 5

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
	harfbuzz_cache_generation   = u64(1)
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
	} else if face := font.system_face() {
		face.path
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
	if font.source_path != '' || layout_test_font_is_configured() {
		return 0
	}
	if face := font.system_face() {
		return face.face_index
	}
	$if macos {
		if font.family.to_lower() in ['lucida grande', 'lucida sans unicode', 'lucida sans',
			'helvetica neue', 'gill sans', 'gill sans std'] {
			return if font.weight >= 600 { 1 } else { 0 }
		}
	}
	return 0
}

// A cold coverage query checks the decoded-face cache for every character.
// Retain its immutable key once, rather than allocating a lookup string per
// glyph. Unsettled explicit-source fallbacks must remain free to change paths.
fn (font &Font) face_cache_key(path string, face_index int) string {
	if font.resolved_path_ != '' {
		if font.resolved_face_cache_key_ != '' { return font.resolved_face_cache_key_ }
		persistent := enter_persistent()
		defer { leave_persistent(persistent) }
		key := '${path}|${face_index}'
		mut mutable_font := unsafe { &Font(font) }
		mutable_font.resolved_face_cache_key_ = key
		return key
	}
	return '${path}|${face_index}'
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
	// HarfBuzz caches outlive any arena entered by the caller.
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
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
			// native glyph replay applies emboldening when the face itself is
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

$if test {
	fn scaled_harfbuzz_font(face voidptr, point_size f32, resolution f32, variations []FontVariationAxis) ?voidptr {
		return scaled_harfbuzz_font_with_policy(face, point_size, resolution, variations, false)
	}
}

fn scaled_harfbuzz_font_with_policy(face voidptr, point_size f32, resolution f32, variations []FontVariationAxis, coretext_hyphens bool) ?voidptr {
	return scaled_harfbuzz_font_with_tracking(face, point_size, resolution, variations,
		coretext_hyphens, point_size)
}

fn scaled_harfbuzz_font_with_tracking(face voidptr, point_size f32, resolution f32,
	variations []FontVariationAxis, coretext_hyphens bool, ptem f32) ?voidptr {
	scale := scale_for_harfbuzz(point_size, resolution)
	mut available := -1
	for index, cached in harfbuzz_scaled_fonts {
		if cached.font == unsafe { nil } {
			if available < 0 { available = index }
			continue
		}
		if cached.face == face && cached.scale == scale && cached.point_size == point_size
			&& cached.ptem == ptem
			&& cached.variations == variations && cached.coretext_hyphens == coretext_hyphens {
			return cached.font
		}
	}
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	mut font := C.hb_font_create(face)
	if font == unsafe { nil } {
		return none
	}
	C.hb_ot_font_set_funcs(font)
	C.hb_font_set_scale(font, scale, scale)
	C.hb_font_set_ptem(font, ptem)
	if variations.len > 0 {
		// FontVariationAxis has hb_variation_t's {tag, value} layout.
		C.hb_font_set_variations(font, variations.data, u32(variations.len))
	}
	$if macos {
		if coretext_hyphens {
			mapped_font := C.vox_hb_with_coretext_hyphens(font)
			if mapped_font != unsafe { nil } {
				C.hb_font_destroy(font)
				font = mapped_font
			}
		}
	}
	mut axes := if available >= 0 {
		unsafe { harfbuzz_scaled_fonts[available].variations }
	} else {
		[]FontVariationAxis{}
	}
	axes.clear()
	axes << variations
	entry := HarfBuzzScaledFont{
		face:             face
		scale:            scale
		point_size:       point_size
		ptem:             ptem
		variations:       axes
		font:             font
		coretext_hyphens: coretext_hyphens
	}
	if available >= 0 {
		harfbuzz_scaled_fonts[available] = entry
	} else {
		harfbuzz_scaled_fonts << entry
	}
	return font
}

fn scale_for_harfbuzz(point_size f32, resolution f32) int {
	scaled_point_size := f64(point_size) * f64(resolution)
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
	if font.harfbuzz_face_ != unsafe { nil }
		&& font.harfbuzz_face_generation_ == harfbuzz_cache_generation {
		return font.harfbuzz_face_
	}
	path := font.font_path()?
	face_index := font.face_index()
	cache_key := font.face_cache_key(path, face_index)
	if face := harfbuzz_document_faces[cache_key] {
		if face != unsafe { nil } {
			font.remember_harfbuzz_face(face)
			return face
		}
	}
	if harfbuzz_document_attempted[cache_key] {
		return none
	}
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
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
	font.remember_harfbuzz_face(face)
	return face
}

fn (font &Font) remember_harfbuzz_face(face voidptr) {
	// Missing explicit sources still use a temporary fallback. Cache only a
	// settled path, just like decoded TrueType faces and pixel metrics do.
	if font.resolved_path_ == '' { return }
	mut mutable_font := unsafe { &Font(font) }
	// Idle retirement advances the generation before another query can use a
	// borrowed native face. Glyph runs keep independent glyph data.
	mutable_font.harfbuzz_face_ = face
	mutable_font.harfbuzz_face_generation_ = harfbuzz_cache_generation
}

// Query the same cmap formats as the legacy decoder without copying or
// decoding outline tables. The blob reference protects this borrowed view;
// no pointer into it escapes, including across native cache retirement.
fn harfbuzz_font_legacy_cmap_glyph(font &Font, code_point u32) ?u16 {
	face := document_harfbuzz_face(font)?
	blob := C.hb_face_reference_blob(face)
	if blob == unsafe { nil } { return none }
	defer { C.hb_blob_destroy(blob) }
	mut length := u32(0)
	data := C.hb_blob_get_data(blob, &length)
	if data == unsafe { nil } || length > 0x7fffffff { return none }
	bytes := unsafe { (&u8(data)).vbytes(int(length)) }
	cmap := font_source_cmap_table(bytes, font.face_index())?
	return font_cmap_table_glyph(cmap, code_point)
}

// x.ttf's cmap reader currently handles only formats 0 and 4. Use HarfBuzz as
// the authoritative glyph-coverage probe as Gfx::Font does upstream, including
// for BMP characters stored only in a format-12 cmap.
fn harfbuzz_font_contains_glyph(font &Font, code_point u32) ?bool {
	face := document_harfbuzz_face(font)?
	hb_font := scaled_harfbuzz_font_with_policy(face, font.point_size, font.shaping_resolution(),
		font.variations(), font.font_rendering_policy == .chromium && system_font_matching_supported())?
	mut glyph := u32(0)
	mapped_code_point := font.shaping_code_point(code_point)
	present := C.hb_font_get_nominal_glyph(hb_font, mapped_code_point, &glyph) != 0 && glyph != 0
	// A temporarily missing explicit source may resolve to another face later.
	// Cache only settled system faces. Explicit fonts retain their legacy cmap
	// coverage semantics, even when another caller probes them with HarfBuzz.
	if code_point < 128 && font.source_path == '' && font.resolved_path_ != ''
		&& font.harfbuzz_face_generation_ == harfbuzz_cache_generation
		&& font.system_face() != none {
		mut mutable_font := unsafe { &Font(font) }
		if mutable_font.ascii_coverage_generation_ != harfbuzz_cache_generation {
			mutable_font.ascii_coverage_known_low_ = 0
			mutable_font.ascii_coverage_known_high_ = 0
			mutable_font.ascii_coverage_present_low_ = 0
			mutable_font.ascii_coverage_present_high_ = 0
			mutable_font.ascii_coverage_generation_ = harfbuzz_cache_generation
		}
		bit := u64(1) << (mapped_code_point & 63)
		if mapped_code_point < 64 {
			mutable_font.ascii_coverage_known_low_ |= bit
			if present { mutable_font.ascii_coverage_present_low_ |= bit }
		} else {
			mutable_font.ascii_coverage_known_high_ |= bit
			if present { mutable_font.ascii_coverage_present_high_ |= bit }
		}
	}
	return present
}

fn emoji_harfbuzz_face() ?voidptr {
	if harfbuzz_emoji_face != unsafe { nil } {
		return harfbuzz_emoji_face
	}
	if harfbuzz_emoji_attempted {
		return none
	}
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
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

__global harfbuzz_bitmap_face_cache = HarfBuzzBitmapFaceCache{}

struct HarfBuzzBitmapFaceCache {
mut:
	// Cleared whenever native faces retire; their addresses can be reused.
	faces map[u64]bool
}

fn harfbuzz_face_has_table(face voidptr, tag u32) bool {
	blob := C.hb_face_reference_table(face, tag)
	if blob == unsafe { nil } {
		return false
	}
	length := C.hb_blob_get_length(blob)
	C.hb_blob_destroy(blob)
	return length > 0
}

fn harfbuzz_face_is_bitmap_face(face voidptr) bool {
	key := u64(face)
	if is_bitmap := harfbuzz_bitmap_face_cache.faces[key] {
		return is_bitmap
	}
	// 'sbix'
	is_bitmap := harfbuzz_face_has_table(face, 0x73626978)
	persistent := enter_persistent()
	harfbuzz_bitmap_face_cache.faces[key] = is_bitmap
	leave_persistent(persistent)
	return is_bitmap
}

// Blink's SimpleFontData::WidthForGlyph(): the glyph's advance without AAT
// 'trak' tracking, which text shaping adds back as a HarfBuzz adjustment. Text
// controls size from this width: SF's 'x' is 7.35px at 14px, while shaped text
// advances 7.19px.
pub fn (font &Font) chromium_strike_glyph_width(code_point u32) ?f32 {
	if font.font_rendering_policy != .chromium { return none }
	face := document_harfbuzz_face(font) or { return none }
	resolution := font.shaping_resolution()
	hb_font := scaled_harfbuzz_font_with_tracking(face, font.point_size, resolution,
		font.variations(), system_font_matching_supported(), font.tracking_size()) or { return none }
	mut glyph := u32(0)
	if C.hb_font_get_nominal_glyph(hb_font, code_point, &glyph) == 0 { return none }
	if !harfbuzz_face_is_bitmap_face(face) && !(font.source_path == '' && font.variations().len > 0) {
		info := C.hb_glyph_info_t{ codepoint: glyph }
		widths := chromium_native_face_widths(font, &info, 1)
		if widths.len == 1 { return widths[0] }
	}
	// HarfBuzz's nominal advance also excludes the shaping-time tracking.
	return f32(f64(C.hb_font_get_glyph_h_advance(hb_font, glyph)) / f64(resolution))
}

// Blink's HarfBuzz font functions also take an outline face's advances from
// its native strike, truncated to 16.16 fixed point, and HarfBuzz adds its GPOS
// adjustments at the same scale. HarfBuzz's own scaling rounds the design
// advance instead, which differs by 1/65536px for about half the glyphs and
// moves glyphs late in a line across a quarter-pixel raster position.
fn chromium_outline_face_advances(font &Font, face voidptr, hb_font voidptr, infos &C.hb_glyph_info_t,
	positions &C.hb_glyph_position_t, count int) []f32 {
	if font.font_rendering_policy != .chromium || count <= 0 || harfbuzz_face_is_bitmap_face(face)
		|| (font.source_path == '' && font.variations().len > 0) {
		return []f32{}
	}
	widths := if font.replay_face() != none {
		chromium_native_face_widths(font, infos, count)
	} else {
		chromium_native_face_widths(font, infos, count)
	}
	if widths.len != count {
		return []f32{}
	}
	mut advances := []f32{len: count}
	for index in 0 .. count {
		position := unsafe { positions[index] }
		if position.x_advance == 0 {
			continue
		}
		nominal := C.hb_font_get_glyph_h_advance(hb_font, unsafe { infos[index] }.codepoint)
		advances[index] = chromium_harfbuzz_advance(widths[index], position.x_advance, nominal)
	}
	return advances
}

// Blink's SkiaScalarToHarfBuzzPosition() truncates a strike width to 16.16
// fixed point. HarfBuzz's positioning adjustments, the difference between its
// shaped and nominal advances, are added at the same scale.
fn chromium_harfbuzz_advance(strike_width f32, x_advance int, nominal_advance int) f32 {
	width := i64(strike_width * f32(65536))
	return f32(f64(width + i64(x_advance) - i64(nominal_advance)) / 65536)
}

fn chromium_bitmap_face_advances(font &Font, face voidptr, infos &C.hb_glyph_info_t, count int) []f32 {
	if font.font_rendering_policy != .chromium || count <= 0 || !harfbuzz_face_is_bitmap_face(face) {
		return []f32{}
	}
	return chromium_native_face_widths(font, infos, count)
}

// CoreText supplies the same untracked strike widths used by glyph rasterization.
fn chromium_native_face_widths(font &Font, infos &C.hb_glyph_info_t, count int) []f32 {
	$if macos {
		mut path := font.font_path() or { return []f32{} }
		if face := font.replay_face() {
			key := face.replay_key()
			tags := face.variations.map(it.tag)
			values := face.variations.map(it.value)
			if C.cpuraster_ct_register_face(key.str, face.path.str, face.postscript_name.str,
				tags.data, values.data, tags.len) == 0 {
				return []f32{}
			}
			path = key
		}
		glyphs := []u16{len: count, init: u16(unsafe { infos[index] }.codepoint)}
		mut widths := []f32{len: count}
		if C.cpuraster_ct_advances(path.str, font.face_index(), font.point_size,
			glyphs.data, count, widths.data) != 0 {
			return widths
		}
	}
	return []f32{}
}

// Chromium-policy text uses the platform's fallback face, such as Apple Color
// Emoji, when the cascade selected one that covers the emoji.
fn font_supplies_chromium_emoji(font &Font, text string) bool {
	if font.font_rendering_policy != .chromium {
		return false
	}
	for character in text.runes() {
		if is_emoji_code_point(u32(character)) {
			return font.contains_glyph(u32(character))
		}
	}
	return false
}

fn utf16_code_units(text string) []u16 {
	mut units := []u16{cap: text.len}
	for character in text.runes_iterator() {
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
	return vunicode.property_named(code_point, 'Default_Ignorable_Code_Point')
}

// Smart punctuation retains the Latin script chosen from an ASCII letter.
// Combining, bidi, non-BMP and other script inputs retain unknown boundaries.
fn harfbuzz_latin_punctuation_units(units []u16) bool {
	mut has_latin := false
	for unit in units {
		if (unit >= `A` && unit <= `Z`) || (unit >= `a` && unit <= `z`) {
			has_latin = true
		} else if unit > 0x7f && unit !in [u16(0x2013), 0x2014, 0x2018, 0x2019, 0x201a, 0x201b,
			0x201c, 0x201d, 0x201e, 0x201f, 0x2026] {
			return false
		}
	}
	return has_latin
}

fn shape_text_with_harfbuzz(initial_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ?ShapedText {
	mut face := unsafe { nil }
	uses_emoji := text_uses_emoji_fallback(text) && !font_supplies_chromium_emoji(font, text)
	if uses_emoji {
		face = emoji_harfbuzz_face()?
	} else {
		face = document_harfbuzz_face(font)?
	}
	resolution := f64(font.shaping_resolution())
	hb_font := scaled_harfbuzz_font_with_tracking(face, font.point_size, f32(resolution), if uses_emoji {
		[]FontVariationAxis{}
	} else {
		font.variations()
	}, !uses_emoji && font.font_rendering_policy == .chromium && system_font_matching_supported(),
		font.tracking_size())?
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
		shaping_text := font.text_for_shaping(text)
		C.hb_buffer_add_utf8(buffer, shaping_text.str, shaping_text.len, 0, -1)
	} else if utf16_units.len > 0 {
		if font.synthesize_ascii_caps {
			mut shaping_units := utf16_units.clone()
			for index, value in shaping_units {
				shaping_units[index] = u16(font.shaping_code_point(u32(value)))
			}
			C.hb_buffer_add_utf16(buffer, shaping_units.data, shaping_units.len, 0, -1)
		} else {
			C.hb_buffer_add_utf16(buffer, utf16_units.data, utf16_units.len, 0, -1)
		}
	}
	if is_ascii {
		C.hb_buffer_set_script(buffer, C.hb_script_from_string(c'Latn', 4))
		C.hb_buffer_set_direction(buffer, if font.font_rendering_policy == .chromium && text_type == .rtl {
			harfbuzz_direction_rtl
		} else {
			harfbuzz_direction_ltr
		})
	} else {
		if text_type == .ltr {
			C.hb_buffer_set_direction(buffer, harfbuzz_direction_ltr)
		} else if text_type == .rtl {
			C.hb_buffer_set_direction(buffer, harfbuzz_direction_rtl)
		}
		C.hb_buffer_guess_segment_properties(buffer)
	}
	mut features := [3]C.hb_feature_t{}
	mut feature_count := u32(0)
	if font.font_rendering_policy == .chromium && letter_spacing != 0 {
		// Blink disables optional common/contextual ligatures for either sign
		// of letter spacing. Required script features remain HarfBuzz defaults.
		for index, tag in [u32(0x6c696761), 0x636c6967, 0x63616c74] {
			features[index] = C.hb_feature_t{ tag: tag, value: 0, start: 0, end: 0xffffffff }
		}
		feature_count = 3
	}
	C.hb_shape(hb_font, buffer, &features[0], feature_count)
	mut glyph_count := u32(0)
	infos := C.hb_buffer_get_glyph_infos(buffer, &glyph_count)
	positions := C.hb_buffer_get_glyph_positions(buffer, &glyph_count)
	// UNSAFE_TO_BREAK is meaningful only at cluster starts. Reject duplicate,
	// decreasing or missing cluster coverage rather than inferring offsets.
	mut known_breaks := (is_ascii || harfbuzz_latin_punctuation_units(utf16_units))
		&& !uses_emoji && text_type == .ltr
		&& font.font_rendering_policy == .chromium && glyph_count > 0
	if known_breaks {
		mut previous := -1
		for index in 0 .. int(glyph_count) {
			cluster := int(unsafe { infos[index] }.cluster)
			if (index == 0 && cluster != 0) || cluster <= previous || cluster >= text_length_in_code_units {
				known_breaks = false
				break
			}
			previous = cluster
		}
	}
	mut native_advances := chromium_bitmap_face_advances(font, face, infos, int(glyph_count))
	if native_advances.len == 0 {
		native_advances = chromium_outline_face_advances(font, face, hb_font, infos, positions, int(glyph_count))
	}
	resolved_letter_spacing := font.quantized_shaping_spacing(letter_spacing)
	resolved_word_spacing := font.quantized_shaping_spacing(word_spacing)
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
			design_advance := if native_advances.len == int(glyph_count) {
				native_advances[index]
			} else {
				f32(f64(position.x_advance) / resolution)
			}
			advance = design_advance + resolved_letter_spacing
			if is_word_separator(code_point) {
				advance += resolved_word_spacing
			}
			// Blink never lets negative letter- or word-spacing make a glyph's
			// advance negative.
			if font.font_rendering_policy == .chromium && advance < 0
				&& (letter_spacing < 0 || word_spacing < 0) {
				advance = 0
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
		offset_x := f32(f64(position.x_offset) / resolution)
		glyphs << Glyph{
			code_point:           code_point
			glyph_index:          int(info.codepoint)
			position:             GlyphPosition{
				x: point_x + offset_x
				// HarfBuzz uses upward-positive font space; replay uses downward-positive y.
				y: f32(f64(-i64(position.y_offset)) / resolution)
			}
			advance:              advance
			offset_x:             offset_x
			length_in_code_units: length_in_code_units
			should_paint:         should_paint
			shaping_break_safety: if known_breaks {
				flags := C.hb_glyph_info_get_glyph_flags(unsafe { &infos[index] })
				if flags & u32(1) == 0 { u8(1) } else { u8(2) }
			} else {
				u8(0)
			}
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
		glyph_run:           glyph_run_with_owned_glyphs(font, text_type, glyphs, if uses_emoji {
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
