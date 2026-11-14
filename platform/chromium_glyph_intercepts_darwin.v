module platform

import math

fn C.cpuraster_ct_font_for_face(path &char, index int, flags &int) voidptr
fn C.cpuraster_ct_exact_copy(base voidptr, size f64) voidptr
fn C.cpuraster_ct_release(font voidptr)
fn C.cpuraster_ct_glyph_path(font voidptr, glyph u16, transform &f64, sx f64, sy f64, elements &&f64) int

// Instantiate the same variable face as glyph replay. The portable TrueType
// reader exposes default contours and cannot apply a font's gvar coordinates.
fn chromium_variable_glyph_intercepts(run &GlyphRun, scale f32, top f32, bottom f32) ?[]f32 {
	font := run.font_
	if font == unsafe { nil } || font.font_rendering_policy != .chromium
		|| font.variations().len == 0 || run.glyphs_.len > 32768
		|| !finite_glyph_coordinate(top) || !finite_glyph_coordinate(bottom) || top > bottom {
		return none
	}
	face := font.replay_face()?
	key := face.replay_key()
	tags := face.variations.map(it.tag)
	values := face.variations.map(it.value)
	if C.cpuraster_ct_register_face(key.str, face.path.str, face.postscript_name.str,
		tags.data, values.data, tags.len) == 0 {
		return none
	}
	mut flags := 0
	base := C.cpuraster_ct_font_for_face(key.str, face.face_index, &flags)
	if base == unsafe { nil } { return none }
	defer { C.cpuraster_ct_release(base) }
	// Intercepts use the canonical unhinted 64px path, then scale the
	// intervals back. Creating a path at the paint size changes rounding.
	outline_scale := font.point_size * scale / 64
	if !(outline_scale > 0) || !finite_glyph_coordinate(outline_scale) { return none }
	strike := C.cpuraster_ct_exact_copy(base, 64)
	if strike == unsafe { nil } { return none }
	defer { C.cpuraster_ct_release(strike) }
	identity := [f64(1), 0, 0, 1, 0, 0]!
	mut intervals := []f32{}
	for glyph in run.glyphs_ {
		if !glyph.should_paint { continue }
		if glyph.glyph_index < 0 || glyph.glyph_index > 65535 { return none }
		mut elements := unsafe { &f64(nil) }
		count := C.cpuraster_ct_glyph_path(strike, u16(glyph.glyph_index), &identity[0], 1, 1, &elements)
		// Spaces have no path. They must not discard the variable outlines
		// already measured for the rest of the run.
		if count < 0 { continue }
		mut extent := GlyphInkExtent{
			band_top:    (top - glyph.position.y * scale) / outline_scale
			band_bottom: (bottom - glyph.position.y * scale) / outline_scale
		}
		mut current := FontGlyphOutlinePoint{}
		mut start := current
		for i in 0 .. count {
			v := unsafe { elements + i * 7 }
			point := unsafe { FontGlyphOutlinePoint{ x: f32(v[1]), y: f32(v[2]), on_curve: true } }
			kind := unsafe { int(v[0]) }
			match kind {
				0 {
					current = point
					start = point
				}
				1 {
					extent.add_line(current, point)
					current = point
				}
				2 {
					end := unsafe { FontGlyphOutlinePoint{ x: f32(v[3]), y: f32(v[4]), on_curve: true } }
					extent.add_quadratic(current, point, end)
					current = end
				}
				3 {
					second := unsafe { FontGlyphOutlinePoint{ x: f32(v[3]), y: f32(v[4]) } }
					end := unsafe { FontGlyphOutlinePoint{ x: f32(v[5]), y: f32(v[6]), on_curve: true } }
					extent.add_cubic(current, point, second, end)
					current = end
				}
				4 {
					extent.add_line(current, start)
					current = start
				}
				else {}
			}
		}
		unsafe { C.free(elements) }
		if extent.left < extent.right {
			intervals << [f32(extent.left) * outline_scale + glyph.position.x * scale,
				f32(extent.right) * outline_scale + glyph.position.x * scale]
		}
	}
	return intervals
}

fn cubic_ink_coordinate(p0 f64, p1 f64, p2 f64, p3 f64, t f64) f64 {
	u := 1 - t
	return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
}

fn (mut extent GlyphInkExtent) add_cubic(p0 FontGlyphOutlinePoint, p1 FontGlyphOutlinePoint,
	p2 FontGlyphOutlinePoint, p3 FontGlyphOutlinePoint) {
	y0, y1, y2, y3 := -f64(p0.y), -f64(p1.y), -f64(p2.y), -f64(p3.y)
	mut stops := [f64(0), 1]
	stops << quadratic_roots_in_unit_interval(3 * (-y0 + 3 * y1 - 3 * y2 + y3), 6 * (y0 - 2 * y1 + y2), 3 * (y1 - y0))
	stops.sort()
	for edge in [extent.band_top, extent.band_bottom] {
		for i in 0 .. stops.len - 1 {
			mut lo, mut hi := stops[i], stops[i + 1]
			a := cubic_ink_coordinate(y0, y1, y2, y3, lo)
			b := cubic_ink_coordinate(y0, y1, y2, y3, hi)
			if edge < math.min(a, b) || edge > math.max(a, b) { continue }
			for _ in 0 .. 40 {
				mid := (lo + hi) * 0.5
				if (cubic_ink_coordinate(y0, y1, y2, y3, mid) < edge) == (a < b) {
					lo = mid
				} else {
					hi = mid
				}
			}
			extent.expand(cubic_ink_coordinate(p0.x, p1.x, p2.x, p3.x, (lo + hi) * 0.5))
		}
	}
	extent.expand_points_inside([p0, p1, p2, p3])
}
