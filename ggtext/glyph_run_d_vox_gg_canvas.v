// Draws the Skia text bridge's CPU glyph runs with gg.canvas (VOX_GG_TEXT=1).
// The bridge calls glyph_run through VoxGGGlyphRun (native_gg_text.h) and
// falls back to Skia whenever it returns 0.
module ggtext

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas
import platform

// Typefaces maps the bridge's CTFontRefs to gg.canvas typefaces. The bridge
// keeps its SkTypefaces (and their CTFonts) alive for the process. Cache
// entries outlive the paint scope that creates them, so they are allocated
// in Vox's persistent arena.
struct Typefaces {
mut:
	fonts     []voidptr
	typefaces []&canvas.Typeface
}

const typefaces = &Typefaces{}

fn typeface(ct_font voidptr) !&canvas.Typeface {
	mut cache := unsafe { typefaces }
	for i, font in cache.fonts {
		if font == ct_font {
			return cache.typefaces[i]
		}
	}
	persistent := platform.enter_persistent()
	defer {
		platform.leave_persistent(persistent)
	}
	face := canvas.Typeface.from_ct_font(ct_font)!
	cache.fonts << ct_font
	cache.typefaces << face
	return face
}

// glyph_run implements VoxGGGlyphRun: it draws one positioned run into BGRA8
// premultiplied pixels with row stride row_pixels, like SkCanvas::drawTextBlob
// with the given SkFont fields, matrix (SkMatrix::get9 order) and SkColor. It
// returns 0 without touching the pixels when gg.canvas cannot draw the run
// exactly.
pub fn glyph_run(pixels &u32, width i32, height i32, row_pixels i32, ct_font voidptr, size f32, scale_x f32, skew_x f32, edging i32, hinting i32, flags i32, glyphs &u16, positions &f32, count i32, origin_x f32, origin_y f32, matrix &f32, color u32, contrast f32, gamma f32) i32 {
	if edging < 0 || edging > 2 || hinting < 0 || hinting > 3 || count <= 0 || width <= 0
		|| height <= 0 || row_pixels < width {
		return 0
	}
	face := typeface(ct_font) or { return 0 }
	font := canvas.Font{
		typeface:         face
		size:             size
		scale_x:          scale_x
		skew_x:           skew_x
		edging:           unsafe { canvas.FontEdging(int(edging)) }
		hinting:          unsafe { canvas.FontHinting(int(hinting)) }
		subpixel:         flags & 1 != 0
		linear_metrics:   flags & 2 != 0
		embolden:         flags & 4 != 0
		baseline_snap:    flags & 8 != 0
		embedded_bitmaps: flags & 16 != 0
	}
	w := int(width)
	h := int(height)
	stride := int(row_pixels)
	mut surface := canvas.new_raster_surface(
		width:  w
		height: h
		props:  canvas.SurfaceProps{
			text_contrast: contrast
			text_gamma:    gamma
		}
	) or { return 0 }
	for y in 0 .. h {
		for x in 0 .. w {
			surface.pixels[y * w + x] = unsafe { pixels[y * stride + x] }
		}
	}
	mut m := [9]f32{}
	for i in 0 .. 9 {
		m[i] = unsafe { matrix[i] }
	}
	surface.set_matrix(canvas.Matrix.values(m))
	n := int(count)
	mut ids := []u16{len: n}
	mut points := []canvas.Point{len: n}
	for i in 0 .. n {
		ids[i] = unsafe { glyphs[i] }
		points[i] = canvas.Point{unsafe { positions[2 * i] }, unsafe { positions[2 * i + 1] }}
	}
	paint := canvas.Paint.rgba8(u8(color >> 16), u8(color >> 8), u8(color), u8(color >> 24))
	// draw_glyphs fills gg.canvas' process-wide strike and glyph caches, which
	// must outlive the paint scope; the surface and arguments above stay in
	// the caller's scope. Its few temporaries are retained with the caches.
	persistent := platform.enter_persistent()
	mut drawn := true
	surface.draw_glyphs(font, ids, points, canvas.Point{origin_x, origin_y}, paint) or {
		drawn = false
	}
	platform.leave_persistent(persistent)
	if !drawn {
		return 0
	}
	for y in 0 .. h {
		for x in 0 .. w {
			unsafe {
				pixels[y * stride + x] = surface.pixels[y * w + x]
			}
		}
	}
	return 1
}
