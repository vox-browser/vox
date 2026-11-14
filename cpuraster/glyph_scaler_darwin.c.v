module cpuraster

$if !cpuraster_freetype ? {

	// CoreText for glyph_run.v's masks (glyph_coretext.h).

	#flag darwin -framework CoreText -framework CoreGraphics -framework CoreFoundation
	#include "@DIR/glyph_coretext.h"

	fn C.cpuraster_ct_font_from_file(path &char, flags &int) voidptr
	fn C.cpuraster_ct_font_for_face(path &char, index int, flags &int) voidptr
	fn C.cpuraster_ct_face_style(path &char, index int, bold &int, italic &int) int
	fn C.cpuraster_ct_register_face(key &char, path &char, postscript_name &char, tags &u32, values &f32, count int) int
	fn C.cpuraster_ct_release(ref voidptr)
	fn C.cpuraster_ct_exact_copy(base voidptr, text_size f64) voidptr
	fn C.cpuraster_ct_bounding_box(font voidptr, out &f64)
	fn C.cpuraster_ct_glyph_metrics(font voidptr, glyph u16, transform &f64, out &f64) int
	fn C.cpuraster_ct_draw_glyph(font voidptr, glyph u16, transform &f64, invertible int, x f64, y f64, pixels voidptr, context_width int, context_height int, width int, height int, color int, foreground u32, smoothing int) int
	fn C.cpuraster_ct_smoothing_behavior() int

	// GlyphFace is SkTypeface_Mac for a font file: its CTFont and whether it
	// has color glyphs or variation axes.
	struct GlyphFace {
		font         voidptr
		color_glyphs bool
		variable     bool
	}

	fn open_glyph_face(path string, index int) ?GlyphFace {
		mut flags := 0
		font := C.cpuraster_ct_font_for_face(&char(path.str), index, &flags)
		if font == unsafe { nil } {
			return none
		}
		return GlyphFace{
			font:         font
			color_glyphs: flags & 1 != 0
			variable:     flags & 2 != 0
		}
	}

	// register_glyph_face names an installed face (its file, PostScript name
	// and variation coordinates) so runs can use key as their font path.
	pub fn register_glyph_face(key string, path string, postscript_name string, tags []u32, values []f32) bool {
		count := if tags.len < values.len { tags.len } else { values.len }
		return C.cpuraster_ct_register_face(&char(key.str), &char(path.str), &char(postscript_name.str),
			tags.data, values.data, count) != 0
	}

	// glyph_face_style reports whether the face is itself bold and italic.
	pub fn glyph_face_style(path string, index int) ?(bool, bool) {
		mut bold := 0
		mut italic := 0
		if C.cpuraster_ct_face_style(&char(path.str), index, &bold, &italic) == 0 {
			return none
		}
		return bold != 0, italic != 0
	}

	fn (f GlyphFace) release() {
		C.cpuraster_ct_release(f.font)
	}

	// SkCTFontCreateExactCopy() at text_size.
	fn (f GlyphFace) exact_copy(text_size f64) ?voidptr {
		font := C.cpuraster_ct_exact_copy(f.font, text_size)
		if font == unsafe { nil } {
			return none
		}
		return font
	}

	fn release_glyph_font(font voidptr) {
		C.cpuraster_ct_release(font)
	}

	// SkFontPriv::GetFontBounds() at size: SkTypeface::getBounds() (the font
	// metrics' x extent, top and bottom of a 2048-point scaler context, scaled
	// back to one point) scaled by size. None when the metrics' bounds are
	// invalid (variable or color fonts), which leaves the blob to its glyphs'
	// bounds.
	fn (f GlyphFace) font_bounds(size f32) ?Rect {
		if f.variable || f.color_glyphs {
			return none
		}
		font := f.exact_copy(2048) or { return none }
		mut box := [4]f64{}
		C.cpuraster_ct_bounding_box(font, &box[0])
		release_glyph_font(font)
		// generateFontMetrics(): fXMin, fTop, fXMax, fBottom.
		x_min := f32(box[0])
		top := f32(-(box[1] + box[3]))
		x_max := f32(box[0] + box[2])
		bottom := f32(-box[1])
		inv := f32(1) / f32(2048)
		unit := Rect{x_min * inv, top * inv, x_max * inv, bottom * inv}
		// SkMatrix::mapRect() for the scale (a translate-only mapping at size 1).
		mut r := if size == 1 {
			Rect{unit.left + 0, unit.top + 0, unit.right + 0, unit.bottom + 0}
		} else {
			l := unit.left * size
			t := unit.top * size
			rr := unit.right * size
			b := unit.bottom * size
			Rect{l + 0, t + 0, rr + 0, b + 0}
		}
		r = Rect{fmin_std(r.left, r.right), fmin_std(r.top, r.bottom), fmax_std(r.left, r.right), fmax_std(r.top,
			r.bottom)}
		if !(r.left < r.right && r.top < r.bottom) {
			return none
		}
		return r
	}

	// GlyphMetrics is CoreText's bounding rect for a glyph under the strike's
	// transform.
	struct GlyphMetrics {
		x      f64
		y      f64
		width  f64
		height f64
	}

	// SkScalerContext_Mac::generateMetrics() up to the bounds conversion: none
	// for an empty glyph (a zero advance without a path, or an empty rect).
	fn glyph_metrics(font voidptr, id u16, transform [6]f64) ?GlyphMetrics {
		mut out := [6]f64{}
		if C.cpuraster_ct_glyph_metrics(font, id, &transform[0], &out[0]) != 0 {
			return none
		}
		// SkCGRectIsEmpty().
		if out[4] <= 0 || out[5] <= 0 {
			return none
		}
		return GlyphMetrics{out[2], out[3], out[4], out[5]}
	}

	fn draw_glyph(font voidptr, id u16, transform [6]f64, invertible bool, x f64, y f64, context_width int, context_height int, width int, height int, color bool, foreground u32) ?[]u32 {
		return draw_glyph_mode(font, id, transform, invertible, x, y, context_width, context_height, width, height, color, foreground, 2)
	}

	fn draw_glyph_mode(font voidptr, id u16, transform [6]f64, invertible bool, x f64, y f64, context_width int, context_height int, width int, height int, color bool, foreground u32, smoothing int) ?[]u32 {
		mut pixels := []u32{len: context_width * context_height}
		if C.cpuraster_ct_draw_glyph(font, id, &transform[0], int(invertible), x, y, pixels.data,
			context_width, context_height, width, height, int(color), foreground, smoothing) == 0 {
			return none
		}
		return pixels
	}

	fn C.cpuraster_ct_glyph_path(font voidptr, glyph u16, transform &f64, sx f64, sy f64, elements &&f64) int
	fn C.free(ptr voidptr)

	// The CoreText path of a glyph through transform and a (sx, sy) scale:
	// seven values per CGPathElement (type, then three points). None when
	// CoreText has no path for it.
	fn glyph_path(font voidptr, id u16, transform [6]f64, sx f64, sy f64) ?[]f64 {
		mut elements := &f64(unsafe { nil })
		count := C.cpuraster_ct_glyph_path(font, id, &transform[0], sx, sy, &elements)
		if count < 0 {
			return none
		}
		if count == 0 || elements == unsafe { nil } {
			return []f64{}
		}
		mut values := []f64{len: count * 7}
		unsafe {
			vmemcpy(values.data, elements, count * 7 * int(sizeof(f64)))
			C.free(elements)
		}
		return values
	}
}
