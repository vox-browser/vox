module cpuraster

$if linux || cpuraster_freetype ? {
	$if linux {
		#pkgconfig freetype2
	} $else {
		// Test-only FreeType backend on macOS, using the oracle's exact FT.
		$if arm64 {
			#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/include
			#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
			#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
		} $else {
			#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/include
			#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
			#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
		}
		#flag -lfreetype
	}
	#include "@DIR/glyph_freetype.h"
	fn C.cpuraster_ft_open(path &char, index int, flags &i32) voidptr
	fn C.cpuraster_ft_release(font voidptr)
	fn C.cpuraster_ft_strike(font voidptr, values &f32) voidptr
	fn C.cpuraster_ft_bounds(font voidptr, glyph u16, sub_x int, sub_y int, smoothing int, bounds &i32) int
	fn C.cpuraster_ft_image(font voidptr, glyph u16, sub_x int, sub_y int, smoothing int, pixels &u8, width int, height int, pitch int) int
	fn C.cpuraster_ft_font_bounds(font voidptr, bounds &f32) int
	fn C.cpuraster_ft_glyph_type(font voidptr, glyph u16, smoothing int) int
	fn C.cpuraster_ft_matrix(font voidptr, values &f32)
	fn C.cpuraster_ft_bitmap(font voidptr, glyph u16, smoothing int, info &i32, pixels &u8) int
	fn C.cpuraster_ft_path(font voidptr, glyph u16, values &&f64) int
	fn C.free(ptr voidptr)

	struct GlyphFace {
		font         voidptr
		color_glyphs bool
		variable     bool
	}

	fn open_glyph_face(path string) ?GlyphFace { return open_freetype_face(path, 0) }

	fn open_freetype_face(path string, index int) ?GlyphFace {
		mut flags := i32(0)
		font := C.cpuraster_ft_open(path.str, index, &flags)
		if font == unsafe { nil } { return none }
		if flags & 12 == 0 {
			C.cpuraster_ft_release(font)
			return none
		}
		return GlyphFace{ font: font, variable: flags & 2 != 0 }
	}

	fn (f GlyphFace) release() { C.cpuraster_ft_release(f.font) }
	fn release_glyph_font(font voidptr) { C.cpuraster_ft_release(font) }

	fn (f GlyphFace) exact_copy(size f64) ?voidptr {
		values := [f32(size), f32(size), f32(1), 0, 0, 1]
		font := C.cpuraster_ft_strike(f.font, values.data)
		if font == unsafe { nil } { return none }
		return font
	}

	fn (f GlyphFace) font_bounds(size f32) ?Rect {
		mut bounds := [4]f32{}
		if C.cpuraster_ft_font_bounds(f.font, &bounds[0]) == 0 { return none }
		return make_sorted(Rect{bounds[0] * size, bounds[1] * size, bounds[2] * size, bounds[3] * size})
	}

	struct GlyphMetrics {
		x      f64
		y      f64
		width  f64
		height f64
	}
	fn glyph_metrics(font voidptr, id u16, transform [6]f64) ?GlyphMetrics { return none }
	fn draw_glyph(font voidptr, id u16, transform [6]f64, invertible bool, x f64, y f64, context_width int, context_height int, width int, height int, color bool, foreground u32) ?[]u32 {
		return none
	}

	fn glyph_path(font voidptr, id u16, transform [6]f64, sx f64, sy f64) ?[]f64 {
		mut values := &f64(unsafe { nil })
		count := int(C.cpuraster_ft_path(font, id, &values))
		if count < 0 { return none }
		defer { unsafe { C.free(values) } }
		mut elements := []f64{len: count * 7}
		if count > 0 { unsafe { vmemcpy(elements.data, values, count * 7 * int(sizeof(f64))) } }
		return elements
	}

	fn new_freetype_strike(face GlyphFace, size f32, device SkAffine, luminance int) ?GlyphStrike {
		m := glyph_strike_matrices_full(size, device, true)
		if !m.invertible { return none }
		r := m.remaining
		values := [m.text_size_x, m.text_size, r.sx, r.ky, r.kx, r.sy]
		font := C.cpuraster_ft_strike(face.font, values.data)
		if font == unsafe { nil } { return none }
		mut scalar := [4]f32{}
		C.cpuraster_ft_matrix(font, &scalar[0])
		return GlyphStrike{
			font:       font
			invertible: true
			table:      mask_gamma_tables[luminance]
			transform:  [f64(scalar[0]), -f64(scalar[1]), -f64(scalar[2]), f64(scalar[3]), 0, 0]!
		}
	}

	fn freetype_run_supported(s &GlyphStrike, glyphs []u16) bool {
		if s.font == unsafe { nil } { return true }
		for id in glyphs {
			kind := C.cpuraster_ft_glyph_type(s.font, id, s.smoothing)
			if kind < 0 { return false }
			if kind in [2, 3] {
				bounds := freetype_glyph_bounds(s, id, 3, 3)
				if bounds.width >= glyph_max_width || bounds.height > max_untiled_dimension {
					return false
				}
			}
		}
		return true
	}

	fn freetype_bitmap_transform(s &GlyphStrike, info [6]i32, sub_x int, sub_y int) SkAffine {
		m := SkAffine{ sx: f32(s.transform[0]), ky: -f32(s.transform[1]), kx: -f32(s.transform[2]), sy: f32(s.transform[3]) }
		return if info[5] == 0 || m.type_mask() != 0 {
			post_translate(m, f32(sub_x) / 4, f32(sub_y) / 4)
		} else {
			m
		}
	}

	fn freetype_bitmap_bounds(s &GlyphStrike, info [6]i32, sub_x int, sub_y int) StrikeGlyph {
		m := freetype_bitmap_transform(s, info, sub_x, sub_y)
		b := map_rect_affine(Rect{f32(info[0]), f32(info[1]), f32(info[0] + info[2]), f32(info[1] + info[3])}, affine_to_matrix(m))
		r := round_out(b)
		return StrikeGlyph{saturate_i16(r.left), saturate_i16(r.top), saturate_u16(r.width()), saturate_u16(r.height()), []u8{}}
	}

	fn freetype_glyph_bounds(s &GlyphStrike, id u16, sub_x int, sub_y int) StrikeGlyph {
		kind := C.cpuraster_ft_glyph_type(s.font, id, s.smoothing)
		if kind in [2, 3] {
			mut info := [6]i32{}
			if C.cpuraster_ft_bitmap(s.font, id, s.smoothing, &info[0], unsafe { nil }) == 0 {
				return StrikeGlyph{}
			}
			return freetype_bitmap_bounds(s, info, sub_x, sub_y)
		}
		mut b := [4]i32{}
		if C.cpuraster_ft_bounds(s.font, id, sub_x, sub_y, s.smoothing, &b[0]) == 0 {
			return StrikeGlyph{}
		}
		return StrikeGlyph{saturate_i16(b[0]), saturate_i16(b[1]), saturate_u16(i64(b[2]) - b[0]), saturate_u16(i64(b[3]) - b[1]), []u8{}}
	}

	fn freetype_make_glyph(s &GlyphStrike, id u16, sub_x int, sub_y int) StrikeGlyph {
		kind := C.cpuraster_ft_glyph_type(s.font, id, s.smoothing)
		if kind in [2, 3] { return freetype_make_bitmap_glyph(s, id, sub_x, sub_y) }
		g := freetype_glyph_bounds(s, id, sub_x, sub_y)
		if g.width == 0 || g.height == 0 || g.width >= glyph_max_width { return g }
		pitch := if s.smoothing == 1 { (g.width + 7) / 8 } else { g.width }
		mut raw := []u8{len: pitch * g.height}
		if C.cpuraster_ft_image(s.font, id, sub_x, sub_y, s.smoothing, raw.data, g.width, g.height, pitch) == 0 {
			return StrikeGlyph{}
		}
		mut image := []u8{len: g.width * g.height}
		for y in 0 .. g.height {
			for x in 0 .. g.width {
				image[y * g.width + x] = if s.smoothing == 1 {
					if raw[y * pitch + x / 8] & (128 >> (x % 8)) != 0 { u8(255) } else { u8(0) }
				} else {
					s.table[raw[y * pitch + x]]
				}
			}
		}
		return StrikeGlyph{g.left, g.top, g.width, g.height, image}
	}

	fn freetype_make_bitmap_glyph(s &GlyphStrike, id u16, sub_x int, sub_y int) StrikeGlyph {
		mut info := [6]i32{}
		if C.cpuraster_ft_bitmap(s.font, id, s.smoothing, &info[0], unsafe { nil }) == 0 {
			return StrikeGlyph{}
		}
		g := freetype_bitmap_bounds(s, info, sub_x, sub_y)
		if g.width == 0 || g.height == 0 || g.width >= glyph_max_width { return g }
		w, h := int(info[2]), int(info[3])
		if w <= 0 || h <= 0 { return StrikeGlyph{} }
		mut source := []u8{len: w * h * 4}
		if C.cpuraster_ft_bitmap(s.font, id, s.smoothing, &info[0], source.data) == 0 {
			return StrikeGlyph{}
		}
		m := freetype_bitmap_transform(s, info, sub_x, sub_y)
		positioned := m44_pre_concat_scale_translate(post_translate(m, -f32(g.left), -f32(g.top)),
			1, f32(info[0]), f32(info[1]))
		mut image := []u8{len: g.width * g.height * 4}
		bitmap := CanvasBitmap{ pixels: source, width: w, height: h, pitch: w * 4, premultiplied: true }
		if !draw_canvas_image_sampled(mut image, g.width, g.height, g.width * 4, 2,
			[positioned.sx, positioned.ky, positioned.kx, positioned.sy, positioned.tx, positioned.ty]!,
			bitmap, [f32(0), 0, f32(w), f32(h)]!, [f32(0), 0, f32(w), f32(h)]!, true, 1, .src_over, [], true) {
			return StrikeGlyph{}
		}
		if info[4] == 0 {
			mut mask := []u8{len: g.width * g.height}
			for i in 0 .. mask.len { mask[i] = s.table[image[i * 4 + 3]] }
			return StrikeGlyph{g.left, g.top, g.width, g.height, mask}
		}
		return StrikeGlyph{g.left, g.top, g.width, g.height, image}
	}
}
