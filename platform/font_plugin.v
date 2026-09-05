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
	platform_serenity_sans_face      &ttf.TTF_File
	platform_serenity_sans_attempted bool
	platform_font_plugin             &FontPlugin
	platform_pixel_metrics_cache     = map[u32]FontPixelMetrics{}
	platform_glyph_units_cache       = map[u32]GlyphUnitsEntry{}
)

// GlyphUnitsEntry memoizes a glyph's point-size-independent metrics: the raw
// advance width in font design units and the resolved glyph index. Both depend
// only on the code point for the fixed layout face, so the per-size advance is
// recovered by scaling the stored units, avoiding a fresh cmap/hmtx lookup on
// every measurement.
struct GlyphUnitsEntry {
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
const sans_serif_fallbacks = ['Arial', 'Helvetica', 'Verdana', 'Trebuchet MS', 'Gill Sans',
	'Noto Sans', 'Avantgarde', 'Optima', 'Arial Narrow', 'Liberation Sans', 'Roboto']
const serif_fallbacks = ['Times', 'Times New Roman', 'Didot', 'Georgia', 'Palatino', 'Bookman',
	'New Century Schoolbook', 'American Typewriter', 'Liberation Serif', 'Roman', 'Noto Serif']

@[heap]
pub struct Font {
pub:
	family     string
	point_size f32
	weight     int = 400
}

pub struct FontPixelMetrics {
pub:
	size                  f32
	x_height              f32
	advance_of_ascii_zero f32
	ascent                f32
	descent               f32
	line_gap              f32
}

pub struct FontGlyphBounds {
pub:
	x_min f32
	x_max f32
	y_min f32
	y_max f32
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

// Gfx::Font::pixel_metrics(). Skia selects the OS/2 typo metrics when the
// USE_TYPO_METRICS bit is present, otherwise the hhea metrics. SerenitySans
// uses typo metrics (819/-205/94 at 1024 units per em).
pub fn (font &Font) pixel_metrics() FontPixelMetrics {
	// pixel_metrics is a pure function of the point size for the fixed layout
	// face, yet Layout calls it hundreds of thousands of times per document.
	// Memoize on the exact f32 bit pattern so repeat sizes are O(1).
	key := unsafe { *(&u32(&font.point_size)) }
	if cached := platform_pixel_metrics_cache[key] {
		return cached
	}
	metrics := font.pixel_metrics_uncached()
	platform_pixel_metrics_cache[key] = metrics
	return metrics
}

fn (font &Font) pixel_metrics_uncached() FontPixelMetrics {
	face := serenity_sans_face() or {
		return FontPixelMetrics{
			size: font.point_size
			x_height: font.point_size * 0.5
			advance_of_ascii_zero: f32(math.round(f64(font.glyph_width(u32(`0`)))))
			ascent: font.point_size * 0.8
			descent: font.point_size * 0.2
		}
	}
	units_per_em := f32(face.units_per_em)
	mut ascent_units := face.ascent
	mut descent_units := i16(-face.descent)
	mut line_gap_units := face.line_gap
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
	if !has_os2_x_height {
		mut mutable_face := unsafe { &ttf.TTF_File(face) }
		x_glyph := mutable_face.map_code(int(`x`))
		_, _, _, x_max_y := mutable_face.read_glyph_dim(x_glyph)
		if x_max_y > 0 {
			x_height_units = i16(x_max_y)
		}
	}
	// SkFont preserves the typeface's one-pixel metrics when constructed with a
	// zero text size, even though glyph advances are zero. Gfx::Font copies
	// those metrics verbatim; Layout therefore still gets a non-zero baseline
	// for font-size:0 text.
	metric_size := if font.point_size == 0 { f32(1) } else { font.point_size }
	scale := metric_size / units_per_em
	zero_advance, _ := font.glyph_metrics(u32(`0`))
	return FontPixelMetrics{
		size: font.point_size
		x_height: f32(x_height_units) * scale
		advance_of_ascii_zero: f32(math.round(f64(zero_advance)))
		ascent: f32(ascent_units) * scale
		descent: f32(descent_units) * scale
		line_gap: f32(line_gap_units) * scale
	}
}

// Gfx::Font metrics used by Layout. Ladybird's Layout tests deliberately select
// Base/res/fonts/SerenitySans-Regular.ttf, so use that same face whenever the
// Ladybird source tree is available. The half-em fallback is retained only for
// standalone deployments which do not provide the test font.
pub fn (font &Font) glyph_width(code_point u32) f32 {
	advance, _ := font.glyph_metrics(code_point)
	return advance
}

// The outline bounds used by Gfx::Path::text(). TrueType's Y axis points up;
// callers map y_max to the visual top and y_min to the visual bottom around
// the text baseline.
pub fn (font &Font) glyph_bounds(glyph_index int) FontGlyphBounds {
	face := serenity_sans_face() or { return FontGlyphBounds{} }
	if glyph_index < 0 || glyph_index > 0xffff {
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
	face := serenity_sans_face()?
	if glyph_index < 0 || glyph_index > 0xffff {
		return none
	}
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	glyph := mutable_face.read_glyph(u16(glyph_index))
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
				x: f32(point.x) * scale
				y: f32(point.y) * scale
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
	face := serenity_sans_face() or { return font.point_size * 0.5, int(code_point) }
	units_per_em := f32(face.units_per_em)
	// The raw advance and glyph index are point-size independent, so cache them
	// per code point and only scale by the requested size here.
	if entry := platform_glyph_units_cache[code_point] {
		return f32(entry.advance_units) * font.point_size / units_per_em, entry.glyph_index
	}
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	// x.ttf currently exposes only cmap formats 0 and 4 and allocates a BMP-
	// sized cache. Unsupported supplementary-plane characters map to .notdef;
	// never index that cache with the full Unicode scalar value.
	if code_point > 0xffff {
		advance, _ := mutable_face.get_horizontal_metrics(0)
		platform_glyph_units_cache[code_point] = GlyphUnitsEntry{
			advance_units: advance
			glyph_index: 0
		}
		return f32(advance) * font.point_size / units_per_em, 0
	}
	glyph_index := mutable_face.map_code(int(code_point))
	advance, _ := mutable_face.get_horizontal_metrics(glyph_index)
	platform_glyph_units_cache[code_point] = GlyphUnitsEntry{
		advance_units: advance
		glyph_index: int(glyph_index)
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
	face := serenity_sans_face() or { return }
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	mutable_face.reset_kern()
}

fn (font &Font) kerning_for_glyph(glyph_index int) f32 {
	face := serenity_sans_face() or { return 0 }
	mut mutable_face := unsafe { &ttf.TTF_File(face) }
	kerning, _ := mutable_face.next_kern(glyph_index)
	return f32(kerning) * font.point_size / f32(mutable_face.units_per_em)
}

fn serenity_sans_face() ?&ttf.TTF_File {
	if platform_serenity_sans_face != unsafe { nil } {
		return platform_serenity_sans_face
	}
	if platform_serenity_sans_attempted {
		return none
	}
	platform_serenity_sans_attempted = true
	mut candidates := []string{}
	if configured := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT') {
		candidates << configured
	}
	if source_root := os.getenv_opt('LADYBIRD_SOURCE_ROOT') {
		candidates << os.join_path(source_root, 'Base', 'res', 'fonts', 'SerenitySans-Regular.ttf')
	}
	repository_root := os.dir(os.dir(@FILE))
	candidates << os.join_path(repository_root, '..', '3rd', 'ladybird', 'Base', 'res', 'fonts', 'SerenitySans-Regular.ttf')
	for path in candidates {
		if !os.is_file(path) {
			continue
		}
		bytes := os.read_bytes(path) or { continue }
		mut face := &ttf.TTF_File{
			buf: bytes
		}
		face.init()
		platform_serenity_sans_face = face
		return face
	}
	return none
}

pub fn (font &Font) is_emoji_font() bool {
	return font.family.to_lower().contains('emoji')
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
		family: plugin.default_font_name_
		point_size: point_size
	}
}

pub fn (plugin &FontPlugin) default_fixed_width_font() ?Font {
	family := plugin.generic_font_name(.ui_monospace)
	if family == '' {
		return none
	}
	return Font{
		family: family
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
