module cpuraster

$if linux || cpuraster_freetype ? {
	struct FreeTypeColorLayer {
		path  Path
		color u32
	}

	fn freetype_color_layers(s &GlyphStrike, id u16) []FreeTypeColorLayer {
		count := int(C.cpuraster_ft_color_layers(s.font, id, unsafe { nil }, unsafe { nil }, s.foreground))
		mut ids := []u16{len: count}
		mut colors := []u32{len: count}
		C.cpuraster_ft_color_layers(s.font, id, ids.data, colors.data, s.foreground)
		mut layers := []FreeTypeColorLayer{cap: count}
		for i, glyph in ids {
			mut values := &f64(unsafe { nil })
			n := int(C.cpuraster_ft_layer_path(s.font, glyph, s.smoothing, &values))
			if n < 0 { continue }
			mut elements := []f64{len: n * 7}
			if n > 0 { unsafe { vmemcpy(elements.data, values, n * 7 * int(sizeof(f64))) } }
			unsafe { C.free(values) }
			layers << FreeTypeColorLayer{glyph_outline_elements(elements), colors[i]}
		}
		return layers
	}

	fn freetype_color_bounds(s &GlyphStrike, id u16, sub_x int, sub_y int) StrikeGlyph {
		layers := freetype_color_layers(s, id)
		return freetype_color_layer_bounds(layers, sub_x, sub_y)
	}

	fn freetype_color_layer_bounds(layers []FreeTypeColorLayer, sub_x int, sub_y int) StrikeGlyph {
		mut bounds := Rect{}
		for layer in layers {
			b := layer.path.bounds() or { continue }
			if b.left >= b.right || b.top >= b.bottom { continue }
			if bounds.left >= bounds.right || bounds.top >= bounds.bottom {
				bounds = b
			} else {
				bounds = Rect{if b.left < bounds.left { b.left } else { bounds.left }, if b.top < bounds.top {
					b.top
				} else {
					bounds.top
				}, if b.right > bounds.right { b.right } else { bounds.right }, if b.bottom > bounds.bottom {
					b.bottom
				} else {
					bounds.bottom
				}}
			}
		}
		if bounds.left >= bounds.right || bounds.top >= bounds.bottom { return StrikeGlyph{} }
		x, y := f32(sub_x) / 4, f32(sub_y) / 4
		b := round_out(Rect{bounds.left + x, bounds.top + y, bounds.right + x, bounds.bottom + y})
		return StrikeGlyph{saturate_i16(b.left), saturate_i16(b.top), saturate_u16(b.width()), saturate_u16(b.height()), []u8{}}
	}

	fn freetype_make_color_glyph(s &GlyphStrike, id u16, sub_x int, sub_y int) StrikeGlyph {
		layers := freetype_color_layers(s, id)
		g := freetype_color_layer_bounds(layers, sub_x, sub_y)
		if g.width == 0 || g.height == 0 || g.width >= glyph_max_width { return g }
		mut pixels := []u8{len: g.width * g.height * 4}
		rc := canvas_raster_clip(g.width, g.height, [])
		matrix := Matrix{1, 0, 0, 1, -f32(g.left) + f32(sub_x) / 4, -f32(g.top) + f32(sub_y) / 4}
		for layer in layers {
			device := layer.path.transform(matrix)
			mut blitter := canvas_blitter(mut pixels, g.width * 4, layer.color, f32(layer.color >> 24) * inv_255, .src_over) or { continue }
			if s.smoothing == 1 {
				fill_path_clip(device, false, &rc, mut blitter)
			} else {
				anti_fill_path_clip(device, false, &rc, mut blitter)
			}
		}
		return StrikeGlyph{g.left, g.top, g.width, g.height, pixels}
	}

	// At path sizes COLR glyphs are replayed as vector drawables through a
	// saveLayer. The 64-point outlines are transformed before rasterization;
	// magnifying the full-size mask does not preserve the edge coverage.
	fn fill_freetype_drawables(mut pixels []u8, pitch int,
		run CanvasGlyphRun, routes []GlyphRoute, face GlyphFace, ctm SkAffine,
		rc &RasterClip, color u32, alpha f32, mode BlendMode, filter ?ColorFilter) {
		if !routes.any(it.kind == .drawable) { return }
		mut strike := new_glyph_strike(face, glyph_path_size, SkAffine{}, 0) or { return }
		defer { strike.release() }
		strike.foreground = (u32(paint_alpha_byte(alpha)) << 24) | (color & 0xffffff)
		for i, route in routes {
			if route.kind != .drawable { continue }
			layers := freetype_color_layers(&strike, run.glyphs[i])
			m := m44_pre_concat_scale_translate(ctm, run.font_size / glyph_path_size,
				run.translation[0] + run.positions[i * 2], run.translation[1] + run.positions[i * 2 + 1])
			bounds := freetype_color_layer_bounds(layers, 0, 0)
			local := Rect{f32(bounds.left), f32(bounds.top), f32(bounds.left + bounds.width), f32(bounds.top + bounds.height)}
			// A transparency-affecting restore must cover the entire parent clip,
			// including offscreen drawables whose source is empty.
			allocation := if blend_affects_transparent_black(mode) {
				rc.bounds()
			} else {
				round_out(map_rect_affine(local, affine_to_matrix(m))).intersect(rc.bounds()) or { continue }
			}
			w, h := allocation.width(), allocation.height()
			shifted := post_translate(m, -f32(allocation.left), -f32(allocation.top))
			mut layer := []u8{len: w * h * 4}
			layer_clip := canvas_raster_clip(w, h, [])
			for item in layers {
				device := item.path.transform(affine_to_matrix(shifted))
				mut blitter := canvas_blitter(mut layer, w * 4, item.color,
					f32(item.color >> 24) * inv_255, .src_over) or { continue }
				if run.smoothing == 1 {
					fill_path_clip(device, false, &layer_clip, mut blitter)
				} else {
					anti_fill_path_clip(device, false, &layer_clip, mut blitter)
				}
			}
			glyph := StrikeGlyph{0, 0, w, h, layer}
			draw_glyph_sprite(mut pixels, pitch, glyph, allocation.left, allocation.top, rc, color, alpha, mode, filter)
		}
	}
}
