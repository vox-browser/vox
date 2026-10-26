// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Platform/FontPlugin.{h,cpp}.
@[has_globals]
module platform

import os
import math
import x.ttf

__global (
	platform_font_faces          = map[string]&ttf.TTF_File{}
	platform_font_face_attempted = map[string]bool{}
	platform_font_plugin         &FontPlugin
	platform_glyph_units_cache   = map[string]GlyphUnitsEntry{}
)

// GlyphUnitsEntry memoizes a glyph's point-size-independent metrics: the raw
// advance width in font design units and the resolved glyph index. The cache is
// keyed by decoded face identity and code point. A missing explicit source
// can initially select a fallback, then resolve to a different face later.
struct GlyphUnitsEntry {
	face          &ttf.TTF_File = unsafe { nil }
	advance_units int
	glyph_index   int
}

pub enum GenericFont {
	cursive
	fantasy
	monospace
	sans_serif
	serif
	ui_monospace
	ui_rounded
	ui_sans_serif
	ui_serif
}

const cursive_fallbacks = ['Comic Sans MS', 'Comic Sans', 'Apple Chancery', 'Bradley Hand',
	'Brush Script MT', 'Snell Roundhand', 'URW Chancery L', 'Dancing Script']
const fantasy_fallbacks = ['Impact', 'Luminari', 'Chalkduster', 'Jazz LET', 'Blippo', 'Stencil Std',
	'Marker Felt', 'Trattatello', 'Coming Soon']
const monospace_fallbacks = ['Andale Mono', 'Courier New', 'Courier', 'FreeMono', 'OCR A Std',
	'Noto Sans Mono', 'DejaVu Sans Mono', 'Droid Sans Mono', 'Liberation Mono']
const sans_serif_fallbacks = ['Arial', 'Helvetica', 'Verdana', 'Trebuchet MS', 'Gill Sans', 'Noto Sans',
	'Avantgarde', 'Optima', 'Arial Narrow', 'Liberation Sans', 'Roboto']
const serif_fallbacks = ['Times', 'Times New Roman', 'Didot', 'Georgia', 'Palatino', 'Bookman',
	'New Century Schoolbook', 'American Typewriter', 'Liberation Serif', 'Roman', 'Noto Serif']

@[heap]
pub struct Font {
pub:
	family     string
	point_size f32
	weight     int = 400
	italic     bool
	// A decoded @font-face source. System fonts leave this empty and resolve
	// through the family cascade.
	source_path           string
	is_invisible          bool
	font_rendering_policy FontRenderingPolicy
	synthesize_ascii_caps bool
	// A character-fallback face selected by the platform cascade.
	system_face_override ?SystemFontFace
mut:
	resolved_system_face_     ?SystemFontFace
	system_face_resolved_     bool
	resolved_path_            string
	resolved_face_cache_key_  string
	decoded_face_             &ttf.TTF_File = unsafe { nil }
	harfbuzz_face_            voidptr       = unsafe { nil }
	harfbuzz_face_generation_ u64
	pixel_metrics_            FontPixelMetrics
	has_pixel_metrics_        bool
}

pub struct FontPixelMetrics {
pub:
	size                  f32
	x_height              f32
	advance_of_ascii_zero f32
	ascent                f32
	descent               f32
	line_gap              f32
	floor_inline_leading  bool
}

pub struct FontGlyphBounds {
pub:
	x_min f32
	x_max f32
	y_min f32
	y_max f32
}

// Gfx::Typeface::bounding_box_in_font_units(), scaled to this Font's CSS-pixel
// size. Text-layout uses the face-wide box to build conservative run bounds
// without querying every glyph while display lists are being recorded.
pub fn (font &Font) typeface_bounds() ?FontGlyphBounds {
	// Installed faces report CoreText's face-wide box without decoding the
	// whole font file.
	if system := font.system_face() {
		bounds := system.metrics
		if bounds.bbox_x_max > bounds.bbox_x_min && bounds.bbox_y_max > bounds.bbox_y_min {
			return FontGlyphBounds{
				x_min: f32(bounds.bbox_x_min)
				x_max: f32(bounds.bbox_x_max)
				y_min: f32(bounds.bbox_y_min)
				y_max: f32(bounds.bbox_y_max)
			}
		}
	}
	face := font_face(font)?
	if face.units_per_em == 0 || face.x_max <= face.x_min || face.y_max <= face.y_min {
		return none
	}
	scale := font.point_size / f32(face.units_per_em)
	return FontGlyphBounds{
		x_min: face.x_min * scale
		x_max: face.x_max * scale
		y_min: face.y_min * scale
		y_max: face.y_max * scale
	}
}

// A scaled TrueType outline point. Gfx::Path::text() asks Skia for these
// contours and appends them to the SVG path; exposing the same data keeps SVG
// text in the path pipeline instead of routing it through inline text paint.
pub struct FontGlyphOutlinePoint {
pub:
	x        f32
	y        f32
	on_curve bool
}

pub struct FontGlyphOutline {
pub:
	contours [][]FontGlyphOutlinePoint
}

// Font handles can be recreated while crossing the CSS/Layout boundary. Test
// whether they still identify the same concrete face and shaping size, as
// Gfx::FontHandle equality does upstream.
pub fn (font &Font) has_same_identity(other &Font) bool {
	if font.point_size != other.point_size || font.weight != other.weight || font.italic != other.italic
		|| font.is_invisible != other.is_invisible
		|| font.font_rendering_policy != other.font_rendering_policy {
		return false
	}
	if font.synthesize_ascii_caps != other.synthesize_ascii_caps {
		return false
	}
	if font_path := font.font_path() {
		other_path := other.font_path() or { return false }
		return font_path == other_path && font.face_index() == other.face_index()
	}
	if other.font_path() != none {
		return false
	}
	return font.family.to_lower() == other.family.to_lower()
}

fn font_u16_at(bytes []u8, offset int) ?u16 {
	if offset < 0 || offset + 2 > bytes.len {
		return none
	}
	return (u16(bytes[offset]) << 8) | u16(bytes[offset + 1])
}

fn font_i16_at(bytes []u8, offset int) ?i16 {
	value := font_u16_at(bytes, offset)?
	return i16(value)
}

fn font_u32_at(bytes []u8, offset int) ?u32 {
	if offset < 0 || offset + 4 > bytes.len {
		return none
	}
	return (u32(bytes[offset]) << 24) | (u32(bytes[offset + 1]) << 16) | (u32(bytes[offset + 2]) << 8) | u32(bytes[offset + 3])
}

fn font_table_offset(bytes []u8, wanted string) ?int {
	count := int(font_u16_at(bytes, 4)?)
	for index in 0 .. count {
		record := 12 + index * 16
		if record + 16 > bytes.len {
			return none
		}
		tag := bytes[record..record + 4].bytestr()
		if tag == wanted {
			return int(font_u32_at(bytes, record + 8)?)
		}
	}
	return none
}

// x.ttf's outline reader requires both TrueType geometry tables. OpenType
// faces with CFF/CFF2 outlines still provide metrics, but cannot enter it.
fn font_face_has_truetype_outlines(face &ttf.TTF_File) bool {
	return 'loca' in face.tables && 'glyf' in face.tables
}

// Gfx::Font::pixel_metrics(). Skia selects the OS/2 typo metrics when the
// USE_TYPO_METRICS bit is present, otherwise the hhea metrics. SerenitySans
// uses typo metrics (819/-205/94 at 1024 units per em) in the deterministic
// screenshot environment.
pub fn (font &Font) pixel_metrics() FontPixelMetrics {
	// Font inputs are immutable. Keep the result on the handle so layout does
	// not allocate and hash a textual cache key for every metrics query.
	if font.has_pixel_metrics_ {
		return font.pixel_metrics_
	}
	metrics := font.pixel_metrics_uncached()
	// An unavailable explicit source can become available later. Its temporary
	// fallback must not become the handle's permanent metrics.
	if font.decoded_face_ != unsafe { nil } || font.system_face() != none {
		mut mutable_font := unsafe { &Font(font) }
		mutable_font.pixel_metrics_ = metrics
		mutable_font.has_pixel_metrics_ = true
	}
	return metrics
}

// Installed faces selected for the Chromium policy use CoreText's metrics, as
// Skia reports them to Blink, without decoding the face file for x.ttf.
fn (font &Font) system_face_pixel_metrics(face SystemFontFace) FontPixelMetrics {
	return FontPixelMetrics{
		size:                  font.point_size
		x_height:              f32(face.metrics.x_height)
		// Blink's `ch` is the unrounded advance of the zero glyph.
		advance_of_ascii_zero: font.glyph_width(u32(`0`))
		ascent:                f32(face.metrics.ascent)
		descent:               f32(face.metrics.descent)
		line_gap:              f32(face.metrics.leading)
	}
}

fn (font &Font) pixel_metrics_uncached() FontPixelMetrics {
	if face := font.system_face() {
		return font.system_face_pixel_metrics(face)
	}
	face := font_face(font) or {
		return FontPixelMetrics{
			size:                  font.point_size
			x_height:              font.point_size * 0.5
			advance_of_ascii_zero: f32(math.round(f64(font.glyph_width(u32(`0`)))))
			ascent:                font.point_size * 0.8
			descent:               font.point_size * 0.2
		}
	}
	zero_advance, _ := font.glyph_metrics(u32(`0`))
	return font.decoded_face_pixel_metrics(face, zero_advance)
}

// Only scalar metrics escape this calculation. Callers that need no retained
// font can supply a temporary decoded face and its unrounded zero advance.
fn (font &Font) decoded_face_pixel_metrics(face &ttf.TTF_File, zero_advance f32) FontPixelMetrics {
	units_per_em := f32(face.units_per_em)
	mut ascent_units := face.ascent
	mut descent_units := i16(-face.descent)
	mut line_gap_units := face.line_gap
	// Start from the hhea values explicitly. x.ttf exposes OS/2 typo values in
	// its convenience fields for fonts that opt into them, so table selection
	// must not depend on that parser detail.
	if hhea := font_table_offset(face.buf, 'hhea') {
		ascent_units = font_i16_at(face.buf, hhea + 4) or { ascent_units }
		hhea_descent := font_i16_at(face.buf, hhea + 6) or { i16(-descent_units) }
		descent_units = i16(-hhea_descent)
		line_gap_units = font_i16_at(face.buf, hhea + 8) or { line_gap_units }
	}
	mut x_height_units := i16(face.units_per_em / 2)
	mut has_os2_x_height := false
	if os2 := font_table_offset(face.buf, 'OS/2') {
		version := font_u16_at(face.buf, os2) or { 0 }
		selection := font_u16_at(face.buf, os2 + 62) or { 0 }
		if selection & u16(0x80) != 0 {
			ascent_units = font_i16_at(face.buf, os2 + 68) or { ascent_units }
			typo_descent := font_i16_at(face.buf, os2 + 70) or { i16(-descent_units) }
			descent_units = i16(-typo_descent)
			line_gap_units = font_i16_at(face.buf, os2 + 72) or { line_gap_units }
		}
		if version >= 2 {
			x_height_units = font_i16_at(face.buf, os2 + 86) or { x_height_units }
			has_os2_x_height = true
		}
	}
	if !has_os2_x_height && font_face_has_truetype_outlines(face) {
		mut mutable_face := unsafe { &ttf.TTF_File(face) }
		x_glyph := font_cmap_glyph(face.buf, u32(`x`))
		_, _, _, x_max_y := mutable_face.read_glyph_dim(x_glyph)
		if x_max_y > 0 {
			x_height_units = i16(x_max_y)
		}
	}
	// SkFont preserves the typeface's one-pixel metrics when constructed with a
	// zero text size, even though glyph advances are zero. Gfx::Font copies
	// those metrics verbatim. Chromium HTML inline layout separately suppresses
	// that fallback strut through inline_metrics().
	metric_size := if font.point_size == 0 { f32(1) } else { font.point_size }
	scale := metric_size / units_per_em
	// Gfx::Font::pixel_metrics() takes SkFont::measureText("0"), and the SkFont
	// Ladybird builds is not sub-pixel positioned, so that advance arrives as a
	// whole number of pixels. The checked-in Layout expectations encode it: at
	// 16px SerenitySans `1ch` is 10px there, not the face's 9.59375px.
	// CoreText's generic-serif selection exposes a 3:1 typographic split while
	// retaining Times New Roman glyph advances. File-backed layout-test fonts
	// instead use their concrete OpenType metrics above.
	generic_serif := font.family.to_lower() in ['serif', 'uiserif']
		&& os.getenv('LADYBIRD_LAYOUT_TEST_FONT') == '' && font.source_path == ''
	return FontPixelMetrics{
		size:                  font.point_size
		x_height:              f32(x_height_units) * scale
		advance_of_ascii_zero: f32(math.round(f64(zero_advance)))
		// Ladybird's CoreText generic-serif cascade exposes typographic metrics
		// with a 3:1 ascent/descent split while retaining the concrete Times New
		// Roman glyph advances. Matching that split keeps CSS line-box baselines
		// identical to the upstream macOS browser.
		ascent:                if generic_serif {
			metric_size * 0.75
		} else {
			f32(ascent_units) * scale
		}
		descent:               if generic_serif {
			metric_size * 0.25
		} else {
			f32(descent_units) * scale
		}
		line_gap:              f32(line_gap_units) * scale
	}
}

// Gfx::Font metrics used by Layout. Ladybird's Layout tests deliberately select
// Base/res/fonts/SerenitySans-Regular.ttf, so use that same face whenever the
// Ladybird source tree is available. The half-em fallback is retained only for
// standalone deployments which do not provide the test font.
pub fn (font &Font) glyph_width(code_point u32) f32 {
	scalar := if code_point > 0x10ffff || (code_point >= 0xd800 && code_point <= 0xdfff) {
		rune(0xfffd)
	} else {
		rune(code_point)
	}
	return shaped_text_width(0, 0, scalar.str(), font, .common)
}

// Gfx::Font::contains_glyph(). A decoded face maps missing characters to the
// .notdef glyph at index zero. Fonts without a concrete source retain the
// synthetic fallback behavior used by standalone and unit-test configurations.
pub fn (font &Font) contains_glyph(code_point u32) bool {
	// Chromium on macOS also accepts CoreText's synthesized hyphens from
	// downloaded fonts, even when their raw cmap has neither character.
	if code_point in [u32(0x2010), 0x2011] && font.uses_system_font_matching() {
		return harfbuzz_font_contains_glyph(font, code_point) or { false }
	}
	// Installed faces chosen by system font matching can use any cmap format;
	// HarfBuzz is the authoritative coverage probe for them.
	if font.system_face() != none {
		return harfbuzz_font_contains_glyph(font, code_point) or { false }
	}
	glyph := font_coverage_glyph(font, code_point) or { return font.source_path == '' }
	if code_point > 0xffff {
		return false
	}
	if glyph != 0 {
		return true
	}
	// NotoEmoji's BMP symbols are exposed through a cmap format which x.ttf
	// does not decode. Keep the narrow compatibility fallback here so ordinary
	// text faces retain the exact coverage behavior used by existing layout.
	if font.family == 'Noto Emoji' {
		return harfbuzz_font_contains_glyph(font, code_point) or { false }
	}
	return false
}

// The outline bounds used by Gfx::Path::text(). TrueType's Y axis points up;
// callers map y_max to the visual top and y_min to the visual bottom around
// the text baseline.
pub fn (font &Font) glyph_bounds(glyph_index int) FontGlyphBounds {
	face := font_face(font) or { return FontGlyphBounds{} }
	if glyph_index < 0 || glyph_index > 0xffff || !font_face_has_truetype_outlines(face) {
		return FontGlyphBounds{}
	}
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	x_min, x_max, y_min, y_max := mutable_face.read_glyph_dim(u16(glyph_index))
	scale := font.point_size / f32(face.units_per_em)
	return FontGlyphBounds{
		x_min: f32(x_min) * scale
		x_max: f32(x_max) * scale
		y_min: f32(y_min) * scale
		y_max: f32(y_max) * scale
	}
}

// The glyph outline consumed by Gfx::Path::text(). Coordinates are scaled to
// the font's point size but retain TrueType's positive-up Y axis; Path::text()
// callers position them relative to the CSS baseline and invert Y there.
pub fn (font &Font) glyph_outline(glyph_index int) ?FontGlyphOutline {
	face := font_face(font)?
	if glyph_index < 0 || glyph_index > 0xffff || !font_face_has_truetype_outlines(face) {
		return none
	}
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	// read_glyph lazily retains outlines (including compound components) in the
	// shared face. They must outlive the document or paint arena decoding them.
	persistent := enter_persistent()
	glyph := mutable_face.read_glyph(u16(glyph_index))
	leave_persistent(persistent)
	if !glyph.valid_glyph || glyph.contour_ends.len == 0 {
		return none
	}
	scale := font.point_size / f32(face.units_per_em)
	mut contours := [][]FontGlyphOutlinePoint{cap: glyph.contour_ends.len}
	mut start := 0
	for contour_end in glyph.contour_ends {
		end := int(contour_end)
		if end < start || end >= glyph.points.len {
			return none
		}
		mut contour := []FontGlyphOutlinePoint{cap: end - start + 1}
		for index in start .. end + 1 {
			point := glyph.points[index]
			contour << FontGlyphOutlinePoint{
				x:        f32(point.x) * scale
				y:        f32(point.y) * scale
				on_curve: point.on_curve
			}
		}
		contours << contour
		start = end + 1
	}
	return FontGlyphOutline{
		contours: contours
	}
}

fn (font &Font) glyph_metrics(code_point u32) (f32, int) {
	return font.glyph_metrics_for_shaping(font.shaping_code_point(code_point))
}

fn (font &Font) glyph_metrics_for_shaping(code_point u32) (f32, int) {
	face := font_face(font) or { return font.point_size * 0.5, int(code_point) }
	units_per_em := f32(face.units_per_em)
	// The raw advance and glyph index are point-size independent, so cache them
	// per code point and only scale by the requested size here.
	// Each entry retains its face as well as its address key. Independently
	// supplied faces must not be collected and have their identity reused while
	// the corresponding metrics remain cached.
	cache_key := '${u64(voidptr(face))}|${code_point}'
	if entry := platform_glyph_units_cache[cache_key] {
		return f32(entry.advance_units) * font.point_size / units_per_em, entry.glyph_index
	}
	// The entry outlives any arena and is the only glyph-index memo needed.
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	// Keep the existing formats 0/4 and supplementary-plane .notdef behavior.
	if code_point > 0xffff {
		advance, _ := mutable_face.get_horizontal_metrics(0)
		platform_glyph_units_cache[cache_key] = GlyphUnitsEntry{
			face:          face
			advance_units: advance
			glyph_index:   0
		}
		return f32(advance) * font.point_size / units_per_em, 0
	}
	glyph_index := font_cmap_glyph(face.buf, code_point)
	advance, _ := mutable_face.get_horizontal_metrics(glyph_index)
	platform_glyph_units_cache[cache_key] = GlyphUnitsEntry{
		face:          face
		advance_units: advance
		glyph_index:   int(glyph_index)
	}
	return f32(advance) * font.point_size / units_per_em, int(glyph_index)
}

// SkTextUtils::GetPath() maps code points to glyphs and advances through the
// SkFont directly; it does not consume the HarfBuzz positions used by normal
// inline text shaping.
pub fn (font &Font) glyph_advance_and_index(code_point u32) (f32, int) {
	advance, glyph_index := font.glyph_metrics(code_point)
	// SkFont::getPos() uses the scaler-context advances. With the default
	// (non-linear-metrics) SkFont used by Gfx::Path::text(), those advances are
	// rounded to whole pixels even though the outline coordinates remain
	// subpixel. SkTextUtils::GetPath() positions each glyph with these values.
	return f32(math.round(f64(advance))), glyph_index
}

fn (font &Font) reset_kerning() {
	_ = font
	face := font_face(font) or { return }
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	mutable_face.reset_kern()
}

fn (font &Font) kerning_for_glyph(glyph_index int) f32 {
	face := font_face(font) or { return 0 }
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	kerning, _ := mutable_face.next_kern(glyph_index)
	return f32(kerning) * font.point_size / f32(mutable_face.units_per_em)
}

// x.ttf asserts every non-head table checksum while parsing, but some installed
// macOS faces ship stale directory checksums. Recompute them in this private
// copy, summing whole big-endian words exactly as x.ttf does.
fn normalize_table_checksums(mut bytes []u8) {
	table_count := int(font_u16_at(bytes, 4) or { return })
	for index in 0 .. table_count {
		record := 12 + index * 16
		if record + 16 > bytes.len {
			return
		}
		if bytes[record..record + 4].bytestr() == 'head' {
			continue
		}
		offset := int(font_u32_at(bytes, record + 8) or { return })
		length := int(font_u32_at(bytes, record + 12) or { return })
		words := (length + 3) >> 2
		if offset < 0 || length < 0 || offset + words * 4 > bytes.len {
			continue
		}
		mut sum := u32(0)
		for word in 0 .. words {
			// The complete padded table was checked above. Read each word
			// directly so checksum normalization does not repeat four bounds
			// checks and construct an optional result for every word.
			position := offset + word * 4
			sum += unsafe {
				(u32(bytes[position]) << 24) | (u32(bytes[position + 1]) << 16)
					| (u32(bytes[position + 2]) << 8) | u32(bytes[position + 3])
			}
		}
		bytes[record + 4] = u8(sum >> 24)
		bytes[record + 5] = u8(sum >> 16)
		bytes[record + 6] = u8(sum >> 8)
		bytes[record + 7] = u8(sum)
	}
}

// Coverage must honor injected and previously decoded faces before borrowing
// the native source. Failed legacy decodes remain authoritative as well.
fn font_coverage_glyph(font &Font, code_point u32) ?u16 {
	if font.decoded_face_ != unsafe { nil } {
		return font_cmap_glyph(font.decoded_face_.buf, code_point)
	}
	path := font.font_path()?
	cache_key := font.face_cache_key(path, font.face_index())
	if face := platform_font_faces[cache_key] {
		return font_cmap_glyph(face.buf, code_point)
	}
	if platform_font_face_attempted[cache_key] { return none }
	if glyph := harfbuzz_font_legacy_cmap_glyph(font, code_point) { return glyph }
	face := font_face(font)?
	return font_cmap_glyph(face.buf, code_point)
}

fn font_face(font &Font) ?&ttf.TTF_File {
	if font.decoded_face_ != unsafe { nil } {
		return font.decoded_face_
	}
	path := font.font_path()?
	face_index := font.face_index()
	cache_key := font.face_cache_key(path, face_index)
	if face := platform_font_faces[cache_key] {
		if font.resolved_path_ != '' {
			mut mutable_font := unsafe { &Font(font) }
			mutable_font.decoded_face_ = face
		}
		return face
	}
	if platform_font_face_attempted[cache_key] {
		return none
	}
	// Cached faces outlive any arena entered by the caller.
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	platform_font_face_attempted[cache_key] = true
	mut bytes := read_outline_face_bytes(path, face_index)?
	face := decode_outline_face(mut bytes)
	platform_font_faces[cache_key] = face
	if font.resolved_path_ != '' {
		mut mutable_font := unsafe { &Font(font) }
		mutable_font.decoded_face_ = face
	}
	return face
}

// Decode into the caller's allocation scope. Publishing the face, when needed,
// remains the responsibility of font_face().
fn decode_outline_face(mut bytes []u8) &ttf.TTF_File {
	normalize_table_checksums(mut bytes)
	// External construction with the current V compiler does not apply these
	// vlib field defaults, but TTF_File.init() writes all 12 PANOSE bytes.
	mut face := &ttf.TTF_File{
		buf:          bytes
		panose_array: []u8{len: 12, init: 0}
		width_scale:  1.0
	}
	$if vox_sparse_ttf ? {
		face.init_for_glyph_indices()
	} $else {
		face.init()
	}
	// Outline/metrics operations use glyph indices and the sparse lookup above.
	// The staged initializer never creates cmaps; discard them on the legacy path.
	face.cmaps = face.cmaps[..0].clone()
	return face
}

pub fn system_font_family_available(family string) bool {
	$if linux {
		return linux_font_path(family, 400, true) != none
	}
	if family.to_lower() == 'noto emoji' {
		return emoji_font_path() != none
	}
	$if macos {
		path := match family.to_lower() {
			// Collection indices are selected alongside these paths by
			// Font.face_index().
			'lucida grande', 'lucida sans unicode', 'lucida sans' {
				'/System/Library/Fonts/LucidaGrande.ttc'
			}
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
			'arial' { '/System/Library/Fonts/Supplemental/Arial.ttf' }
			else { '' }
		}
		return path != '' && os.is_file(path)
	}
	return false
}

pub fn (font &Font) is_emoji_font() bool {
	// Match Gfx::Font's layout-test heuristic. Family matching here is
	// intentionally case-sensitive: the bundled monochrome "Noto Emoji" face
	// is a symbol fallback, rather than a color-emoji face, and may therefore
	// supply the marker suffix space together with its symbol glyph.
	return font.family.contains('emoji')
}

@[heap]
pub struct FontPlugin {
mut:
	is_layout_test_mode_ bool
	installed_font_names []string
	generic_font_names   map[GenericFont]string
	symbol_font_names_   []string
	default_font_name_   string
}

pub fn FontPlugin.new(is_layout_test_mode bool, installed_font_names []string, is_macos bool) &FontPlugin {
	mut plugin := &FontPlugin{
		is_layout_test_mode_: is_layout_test_mode
		installed_font_names: installed_font_names.clone()
	}
	plugin.update_generic_fonts()
	plugin.default_font_name_ = plugin.generic_font_name(.ui_sans_serif)
	plugin.symbol_font_names_ = if is_layout_test_mode {
		['Noto Emoji']
	} else if is_macos {
		['Apple Color Emoji', 'Apple Symbols']
	} else {
		['Noto Color Emoji', 'Noto Sans Symbols']
	}
	return plugin
}

pub fn FontPlugin.the() &FontPlugin {
	if platform_font_plugin == unsafe { nil } {
		panic('FontPlugin is not installed')
	}
	return platform_font_plugin
}

pub fn FontPlugin.is_initialized() bool {
	return platform_font_plugin != unsafe { nil }
}

// FontComputer consumes this through its platform boundary. Layout tools do
// not install an embedder singleton, but selecting the deterministic document
// face is also the signal that they use Ladybird's bundled symbol fallback.
pub fn symbol_font_names_for_environment() []string {
	if FontPlugin.is_initialized() {
		return FontPlugin.the().symbol_font_names()
	}
	if os.getenv('LADYBIRD_LAYOUT_TEST_FONT') != '' {
		return ['Noto Emoji']
	}
	return []
}

pub fn FontPlugin.install(plugin &FontPlugin) {
	if platform_font_plugin != unsafe { nil } {
		panic('FontPlugin already installed')
	}
	platform_font_plugin = plugin
}

pub fn (plugin &FontPlugin) is_layout_test_mode() bool {
	return plugin.is_layout_test_mode_
}

fn (plugin &FontPlugin) select_font(fallbacks []string) string {
	if plugin.is_layout_test_mode_ {
		return 'SerenitySans'
	}
	for fallback in fallbacks {
		if fallback in plugin.installed_font_names {
			return fallback
		}
	}
	return ''
}

pub fn (mut plugin FontPlugin) update_generic_fonts() {
	plugin.generic_font_names[.cursive] = plugin.select_font(cursive_fallbacks)
	plugin.generic_font_names[.fantasy] = plugin.select_font(fantasy_fallbacks)
	plugin.generic_font_names[.monospace] = plugin.select_font(monospace_fallbacks)
	plugin.generic_font_names[.sans_serif] = plugin.select_font(sans_serif_fallbacks)
	plugin.generic_font_names[.serif] = plugin.select_font(serif_fallbacks)
	plugin.generic_font_names[.ui_monospace] = plugin.select_font(monospace_fallbacks)
	plugin.generic_font_names[.ui_rounded] = plugin.select_font(sans_serif_fallbacks)
	plugin.generic_font_names[.ui_sans_serif] = plugin.select_font(sans_serif_fallbacks)
	plugin.generic_font_names[.ui_serif] = plugin.select_font(serif_fallbacks)
}

pub fn (plugin &FontPlugin) generic_font_name(generic GenericFont) string {
	return plugin.generic_font_names[generic]
}

pub fn (plugin &FontPlugin) default_font(point_size f32) ?Font {
	if plugin.default_font_name_ == '' {
		return none
	}
	return Font{
		family:     plugin.default_font_name_
		point_size: point_size
	}
}

pub fn (plugin &FontPlugin) default_fixed_width_font() ?Font {
	family := plugin.generic_font_name(.ui_monospace)
	if family == '' {
		return none
	}
	return Font{
		family:     family
		point_size: 12
	}
}

pub fn (plugin &FontPlugin) symbol_font_names() []string {
	return plugin.symbol_font_names_.clone()
}

pub struct FontPluginRegistry {
mut:
	plugin ?&FontPlugin
}

pub fn (mut registry FontPluginRegistry) install(plugin &FontPlugin) {
	if registry.plugin != none { panic('FontPlugin already installed') }
	registry.plugin = plugin
}

pub fn (registry &FontPluginRegistry) get() &FontPlugin {
	return registry.plugin or { panic('FontPlugin is not installed') }
}
