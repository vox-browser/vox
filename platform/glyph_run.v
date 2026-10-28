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
	code_point  u32
	glyph_index int
	position    GlyphPosition
	advance     f32
	// HarfBuzz's horizontal placement, which position.x already includes.
	offset_x             f32
	length_in_code_units int  = 1
	should_paint         bool = true
	// Zero means unknown; HarfBuzz marks proven ASCII boundaries as safe (1)
	// or unsafe (2). Keep manually constructed/fallback glyphs conservative.
	shaping_break_safety u8
}

// Conservative painted bounds in CSS pixels, relative to a run's baseline
// origin. This is the V counterpart of Layout's retained FloatRect.
pub struct GlyphRunBounds {
pub:
	x      f32
	y      f32
	width  f32
	height f32
}

// The exact shaped advance of the ASCII whitespace at the end of a run.
// Layout retains this so removing end-of-line whitespace is the inverse of
// shaping, including kerning and text spacing.
pub struct TrailingWhitespace {
pub:
	length_in_code_units int
	advance              f32
}

pub struct ShapedText {
pub:
	glyph_run           &GlyphRun = unsafe { nil }
	trailing_whitespace TrailingWhitespace
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
	bounding_box_      GlyphRunBounds
	replay_data_dirty_ bool
mut:
	shared_glyphs_      bool
	shared_replay_data_ bool
}

fn finite_glyph_coordinate(value f32) bool {
	return !math.is_nan(value) && value != f32(math.inf(1)) && value != f32(math.inf(-1))
}

fn glyph_run_face_font(font &Font, face GlyphRunFace) &Font {
	if face == .emoji {
		if path := emoji_font_path() {
			return &Font{
				family:      'emoji'
				point_size:  font.point_size
				weight:      font.weight
				source_path: path
			}
		}
	}
	return font
}

// LibGfx::glyph_run_bounding_box(). Glyph positions in this V boundary are
// already baseline-relative, whereas LibGfx's DrawGlyph stores a top-relative
// y and adds the font ascent before expanding the face bounds.
pub fn glyph_run_bounding_box(font &Font, glyphs []Glyph, face GlyphRunFace) GlyphRunBounds {
	mut min_x := f32(math.inf(1))
	mut min_y := f32(math.inf(1))
	mut max_x := f32(math.inf(-1))
	mut max_y := f32(math.inf(-1))
	mut has_painted_glyphs := false
	for glyph in glyphs {
		if !glyph.should_paint {
			continue
		}
		origin_x := glyph.position.x
		origin_y := glyph.position.y
		if !finite_glyph_coordinate(origin_x) || !finite_glyph_coordinate(origin_y) {
			return GlyphRunBounds{}
		}
		min_x = f32(math.min(min_x, origin_x))
		min_y = f32(math.min(min_y, origin_y))
		max_x = f32(math.max(max_x, origin_x))
		max_y = f32(math.max(max_y, origin_y))
		has_painted_glyphs = true
	}
	if !has_painted_glyphs {
		return GlyphRunBounds{}
	}

	run_font := glyph_run_face_font(font, face)
	if font_bounds := run_font.typeface_bounds() {
		left := min_x + font_bounds.x_min
		top := min_y - font_bounds.y_max
		right := max_x + font_bounds.x_max
		bottom := max_y - font_bounds.y_min
		return GlyphRunBounds{left, top, right - left, bottom - top}
	}

	// Bitmap-only and synthetic fonts may not expose a face-wide box. Match
	// LibGfx's fallback by uniting the painted glyph extents that are available.
	mut left := f32(math.inf(1))
	mut top := f32(math.inf(1))
	mut right := f32(math.inf(-1))
	mut bottom := f32(math.inf(-1))
	mut has_extent := false
	for glyph in glyphs {
		if !glyph.should_paint {
			continue
		}
		bounds := run_font.glyph_bounds(glyph.glyph_index)
		if bounds.x_max <= bounds.x_min || bounds.y_max <= bounds.y_min {
			continue
		}
		left = f32(math.min(left, glyph.position.x + bounds.x_min))
		top = f32(math.min(top, glyph.position.y - bounds.y_max))
		right = f32(math.max(right, glyph.position.x + bounds.x_max))
		bottom = f32(math.max(bottom, glyph.position.y - bounds.y_min))
		has_extent = true
	}
	if !has_extent {
		return GlyphRunBounds{}
	}
	return GlyphRunBounds{left, top, right - left, bottom - top}
}

pub fn GlyphRun.new(font &Font, text_type GlyphRunTextType, glyphs []Glyph) &GlyphRun {
	return GlyphRun.new_with_face(font, text_type, glyphs, .document)
}

pub fn GlyphRun.new_with_face(font &Font, text_type GlyphRunTextType, glyphs []Glyph,
	face GlyphRunFace) &GlyphRun {
	return glyph_run_with_owned_glyphs(font, text_type, glyphs.clone(), face)
}

// Layout needs the shaped positions and advance while splitting a line, but
// its final glyph vector is not ready for retained playback yet. Preserve the
// original coordinates and defer replay buffers and ink bounds to publication.
pub fn (run &GlyphRun) slice_for_layout(start int, length int) &GlyphRun {
	glyphs := run.glyphs_[start..start + length].clone()
	mut width := f32(0)
	mut space_width := f32(run.font().point_size * 0.5)
	for glyph in glyphs {
		width += glyph.advance
		if glyph.code_point == u32(` `) { space_width = glyph.advance }
	}
	return &GlyphRun{
		font_:              run.font()
		text_type_:         run.text_type()
		face_:              run.face()
		width_:             width
		glyphs_:            glyphs
		space_width:        space_width
		replay_data_dirty_: true
	}
}

// Copy and translate a slice without an intermediate caller-owned vector.
// Replay buffers are built by refresh_replay_data() at line publication.
// Intrinsic probes can measure the private glyph vector without building them.
pub fn (run &GlyphRun) translated_slice_for_layout(start int, length int, x f32, y f32) &GlyphRun {
	mut glyphs := run.glyphs_[start..start + length].clone()
	mut width := f32(0)
	mut space_width := f32(run.font().point_size * 0.5)
	for mut glyph in glyphs {
		glyph.position.translate_by(x, y)
		width += glyph.advance
		if glyph.code_point == u32(` `) { space_width = glyph.advance }
	}
	return &GlyphRun{
		font_:              run.font()
		text_type_:         run.text_type()
		face_:              run.face()
		width_:             width
		glyphs_:            glyphs
		space_width:        space_width
		replay_data_dirty_: true
	}
}

// Materialize a nonempty, already checked LTR context range. Measure its
// advance locally so paragraph pen rounding cannot shift the retained pixels.
// The completed line must refresh replay data before publication.
pub fn (run &GlyphRun) ltr_context_slice_for_layout(first int, end int) ShapedText {
	// Blink sums the 16.16 advances of a line's part of an item exactly from
	// its first glyph, then converts each sum to float. Subtracting the float
	// pens of a paragraph-long run instead moves glyphs hundreds of pixels in
	// by a few ULPs, enough to change their quarter-pixel raster position.
	// The slice starts at its first glyph's placement, which HarfBuzz's split
	// 'kern' adjustments can move, and ends at the next glyph's.
	mut glyphs := run.glyphs_[first..end].clone()
	origin := f64(glyphs[0].offset_x)
	mut local := f64(0)
	for mut glyph in glyphs {
		glyph.position.x = f32(local + f64(glyph.offset_x) - origin)
		local += f64(glyph.advance)
	}
	next_offset := if end < run.glyphs_.len { f64(run.glyphs_[end].offset_x) } else { f64(0) }
	sliced := &GlyphRun{
		font_:              run.font()
		text_type_:         .ltr
		face_:              run.face()
		width_:             f32(local + next_offset - origin)
		glyphs_:            glyphs
		space_width:        run.space_width
		replay_data_dirty_: true
	}
	mut trailing_length := 0
	mut trailing_advance := f32(0)
	for index := glyphs.len - 1; index >= 0; index-- {
		glyph := glyphs[index]
		if glyph.code_point != u32(` `) {
			break
		}
		trailing_length += glyph.length_in_code_units
		trailing_advance += glyph.advance
	}
	return ShapedText{
		glyph_run:           sliced
		trailing_whitespace: TrailingWhitespace{
			length_in_code_units: trailing_length
			advance:              trailing_advance
		}
	}
}

// The caller transfers a private glyph vector. Keep this boundary private so
// public constructors retain their independent copy of caller-owned storage.
fn glyph_run_with_owned_glyphs(font &Font, text_type GlyphRunTextType, glyphs []Glyph,
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
		if !glyph.should_paint {
			continue
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
		glyphs_:          glyphs
		space_width:      space_width
		glyph_indices_:   glyph_indices
		glyph_positions_: glyph_positions
		bounding_box_:    glyph_run_bounding_box(font, glyphs, face)
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

pub fn (run &GlyphRun) bounding_box() GlyphRunBounds {
	return run.bounding_box_
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
		bounding_box_:      run.bounding_box_
		replay_data_dirty_: run.replay_data_dirty_
	}
}

// Intrinsic text caches own immutable runs. Borrow their storage until a line
// actually modifies it; most probe chunks are consumed without any mutation.
// Call invalidate_replay_data() before editing a fork's public glyph storage.
pub fn (run &GlyphRun) fork_for_layout() &GlyphRun {
	return &GlyphRun{
		glyphs_:             run.glyphs_
		font_:               run.font_
		text_type_:          run.text_type_
		face_:               run.face_
		width_:              run.width_
		space_width:         run.space_width
		glyph_indices_:      run.glyph_indices_
		glyph_positions_:    run.glyph_positions_
		bounding_box_:       run.bounding_box_
		replay_data_dirty_:  run.replay_data_dirty_
		shared_glyphs_:      true
		shared_replay_data_: true
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
	if run.shared_replay_data_ {
		run.glyph_indices_ = []u16{cap: run.glyphs_.len}
		run.glyph_positions_ = []f64{cap: run.glyphs_.len * 2}
		run.shared_replay_data_ = false
	} else {
		run.glyph_indices_.clear()
		run.glyph_positions_.clear()
	}
	for glyph in run.glyphs_ {
		if !glyph.should_paint {
			continue
		}
		run.glyph_indices_ << u16(glyph.glyph_index)
		run.glyph_positions_ << f64(glyph.position.x)
		run.glyph_positions_ << f64(glyph.position.y)
	}
	run.bounding_box_ = glyph_run_bounding_box(run.font_, run.glyphs_, run.face_)
	run.replay_data_dirty_ = false
}

pub fn (mut run GlyphRun) invalidate_replay_data() {
	if run.shared_glyphs_ {
		run.glyphs_ = run.glyphs_.clone()
		run.shared_glyphs_ = false
	}
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

struct GlyphInkExtent {
	band_top    f64
	band_bottom f64
mut:
	left  f64 = math.inf(1)
	right f64 = math.inf(-1)
}

fn (mut extent GlyphInkExtent) expand(x f64) {
	extent.left = math.min(extent.left, x)
	extent.right = math.max(extent.right, x)
}

fn (extent &GlyphInkExtent) overlaps_band(top f64, bottom f64) bool {
	return extent.band_top <= bottom && top <= extent.band_bottom
}

fn (mut extent GlyphInkExtent) expand_points_inside(points []FontGlyphOutlinePoint) {
	for point in points {
		y := -f64(point.y)
		if extent.band_top < y && y < extent.band_bottom {
			extent.expand(f64(point.x))
		}
	}
}

fn (mut extent GlyphInkExtent) add_line(p0 FontGlyphOutlinePoint, p1 FontGlyphOutlinePoint) {
	x0 := f64(p0.x)
	y0 := -f64(p0.y)
	x1 := f64(p1.x)
	y1 := -f64(p1.y)
	if !extent.overlaps_band(math.min(y0, y1), math.max(y0, y1)) {
		return
	}
	if y1 != y0 {
		for offset in [extent.band_top, extent.band_bottom] {
			t := (offset - y0) / (y1 - y0)
			if t >= 0 && t < 1 {
				extent.expand(x0 + t * (x1 - x0))
			}
		}
	}
	extent.expand_points_inside([p0, p1])
}

fn quadratic_roots_in_unit_interval(a f64, b f64, c f64) []f64 {
	mut roots := []f64{cap: 2}
	if a == 0 {
		if b != 0 {
			t := -c / b
			if t >= 0 && t <= 1 {
				roots << t
			}
		}
		return roots
	}
	discriminant := b * b - 4.0 * a * c
	if discriminant < 0 {
		return roots
	}
	q := -0.5 * (b + math.copysign(math.sqrt(discriminant), b))
	first := q / a
	if first >= 0 && first <= 1 {
		roots << first
	}
	if q != 0 {
		second := c / q
		if second >= 0 && second <= 1 {
			roots << second
		}
	}
	return roots
}

fn (mut extent GlyphInkExtent) add_quadratic(p0 FontGlyphOutlinePoint, p1 FontGlyphOutlinePoint, p2 FontGlyphOutlinePoint) {
	x0 := f64(p0.x)
	y0 := -f64(p0.y)
	x1 := f64(p1.x)
	y1 := -f64(p1.y)
	x2 := f64(p2.x)
	y2 := -f64(p2.y)
	if !extent.overlaps_band(math.min(y0, math.min(y1, y2)), math.max(y0, math.max(y1, y2))) {
		return
	}
	a := y0 - 2.0 * y1 + y2
	b := 2.0 * (y1 - y0)
	for offset in [extent.band_top, extent.band_bottom] {
		for t in quadratic_roots_in_unit_interval(a, b, y0 - offset) {
			u := 1.0 - t
			extent.expand(u * u * x0 + 2.0 * u * t * x1 + t * t * x2)
		}
	}
	extent.expand_points_inside([p0, p1, p2])
}

fn outline_midpoint(first FontGlyphOutlinePoint, second FontGlyphOutlinePoint) FontGlyphOutlinePoint {
	return FontGlyphOutlinePoint{
		x:        (first.x + second.x) * 0.5
		y:        (first.y + second.y) * 0.5
		on_curve: true
	}
}

// LibGfx::glyph_run_glyph_intercepts(). Return the horizontal ink intervals where the shaped
// glyph outlines cross a band in blob-local coordinates. TrueType contours contain quadratic
// off-curve control points; consecutive controls imply an on-curve midpoint.
pub fn (run &GlyphRun) glyph_intercepts(scale f32, y_top f32, y_bottom f32) []f32 {
	if !(scale > 0) || math.is_nan(scale) || scale == f32(math.inf(1)) {
		return []f32{}
	}
	mut intervals := []f32{}
	for glyph in run.glyphs_ {
		if !glyph.should_paint {
			continue
		}
		outline := run.font_.glyph_outline(glyph.glyph_index) or { continue }
		mut extent := GlyphInkExtent{
			band_top:    (f64(y_top) - f64(glyph.position.y) * f64(scale)) / f64(scale)
			band_bottom: (f64(y_bottom) - f64(glyph.position.y) * f64(scale)) / f64(scale)
		}
		for contour in outline.contours {
			if contour.len < 2 {
				continue
			}
			first := contour[0]
			last := contour[contour.len - 1]
			mut current := if first.on_curve {
				first
			} else if last.on_curve {
				last
			} else {
				outline_midpoint(last, first)
			}
			start := current
			mut index := if first.on_curve { 1 } else { 0 }
			mut consumed := if first.on_curve { 1 } else { 0 }
			for consumed < contour.len {
				point := contour[index % contour.len]
				if point.on_curve {
					extent.add_line(current, point)
					current = point
					index++
					consumed++
					continue
				}
				next := contour[(index + 1) % contour.len]
				if next.on_curve {
					extent.add_quadratic(current, point, next)
					current = next
					index += 2
					consumed += 2
				} else {
					midpoint := outline_midpoint(point, next)
					extent.add_quadratic(current, point, midpoint)
					current = midpoint
					index++
					consumed++
				}
			}
			extent.add_line(current, start)
		}
		if extent.left < extent.right {
			origin_x := f64(glyph.position.x) * f64(scale)
			intervals << f32(extent.left * f64(scale) + origin_x)
			intervals << f32(extent.right * f64(scale) + origin_x)
		}
	}
	return intervals
}

fn is_word_separator(code_point u32) bool {
	// Match the interoperable subset used by LibGfx. A collapsed line feed can
	// remain in shaped input and behaves like a space there.
	return code_point in [u32(0x0020), 0x00a0, 0x000a]
}

fn is_ascii_space_for_shaping(code_unit u16) bool {
	return code_unit in [u16(0x09), 0x0a, 0x0b, 0x0c, 0x0d, 0x20]
}

fn utf16_units_for_shaping(text string) []u16 {
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

fn trailing_whitespace_length(text string) int {
	mut length := 0
	// All shaping whitespace is ASCII, so each trailing byte is also exactly
	// one UTF-16 code unit. The preceding text needs no decoding or storage.
	for length < text.len && is_ascii_space_for_shaping(u16(text[text.len - length - 1])) {
		length++
	}
	return length
}

// Gfx::shape_text()'s layout-facing contract. Native HarfBuzz/CoreText
// shaping belongs behind the platform font provider; this deterministic
// fallback preserves glyph positions, UTF-16 lengths, text spacing and run
// direction so Layout consumes the same shaped-run representation.
pub fn shape_text(initial_x f32, letter_spacing f32, text string, font &Font, text_type GlyphRunTextType) &GlyphRun {
	return shape_text_with_spacing(initial_x, letter_spacing, 0, text, font, text_type).glyph_run
}

pub fn shape_text_with_spacing(initial_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ShapedText {
	return shape_text_cached(initial_x, letter_spacing, word_spacing, text, font, text_type)
}

fn shape_text_uncached(initial_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ShapedText {
	if shaped := shape_text_with_harfbuzz(initial_x, letter_spacing, word_spacing, text, font, text_type) {
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
	resolution := f64(font.shaping_resolution())
	for character in text.runes() {
		code_point := u32(character)
		base_advance, glyph_index := font.glyph_metrics(code_point)
		is_default_ignorable := code_point_is_default_ignorable(code_point)
		should_paint := !font.is_invisible && !is_default_ignorable
		// Match the selected HarfBuzz scale. Quantize each value separately,
		// before accumulating it, just as TextLayout.cpp does when dividing the
		// integer hb_glyph_position_t fields by text_shaping_resolution.
		mut advance := f32(0)
		if !is_default_ignorable {
			x += f32(math.round(f64(font.kerning_for_glyph(glyph_index)) * resolution) / resolution)
			advance = f32(math.round(f64(base_advance) * resolution) / resolution) + letter_spacing
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
			glyphs[index].position.x = initial_x + width - (glyphs[index].position.x - initial_x) - glyphs[index].advance
		}
	}
	// Avoid leaking negative zero through the fixed-point conversion used by
	// layout geometry.
	if math.abs(x) < f32(0.000001) {
		x = 0
	}
	return ShapedText{
		glyph_run:           glyph_run_with_owned_glyphs(font, text_type, glyphs, .document)
		trailing_whitespace: TrailingWhitespace{
			length_in_code_units: trailing_length
			advance:              trailing_advance
		}
	}
}
