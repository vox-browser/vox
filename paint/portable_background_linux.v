module main

import cpuraster
import css
import layout
import math
import painting
import platform

fn portable_device_transform(matrix [6]f64, page_x f32, page_y f32,
	scale f64) painting.Affine {
	m := normalized_paint_transform(matrix)
	return painting.Affine{
		a: m[0] * scale
		b: m[1] * scale
		c: m[2] * scale
		d: m[3] * scale
		e: (m[4] + f64(page_x)) * scale
		f: (m[5] + f64(page_y)) * scale
	}
}

fn portable_pixel_bounds(rect painting.Rect) painting.IntRect {
	if rect.is_empty() { return painting.IntRect{} }
	left := int(math.floor(rect.x))
	top := int(math.floor(rect.y))
	return painting.IntRect{left, top, int(math.ceil(rect.right())) - left, int(math.ceil(rect.bottom())) - top}
}

fn (app &BrowserApp) portable_device_viewport(page_y f32) painting.Rect {
	scale := f64(app.ctx.scale)
	top := math.max(0, f64(app.paint_replay_viewport_top(page_y)))
	bottom := f64(app.ctx.height - app.status_height())
	return painting.Rect{0, top * scale, f64(app.ctx.width) * scale, (bottom - top) * scale}
}

fn (mut app BrowserApp) begin_portable_background_text_clip(command &layout.PaintCommand,
	page_x f32, page_y f32) {
	transform := portable_device_transform(command.transform, page_x, page_y, f64(app.ctx.scale))
	local := painting.Rect{command.x, command.y, command.width, command.height}
	bounds := portable_pixel_bounds(transform.map_rect(local).intersection(app.portable_device_viewport(page_y)))
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	if pixels.len > 0 {
		matrix := [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d),
			f32(transform.e - f64(bounds.x)), f32(transform.f - f64(bounds.y))]!
		mut cache := document_glyph_cache()
		for clip_run in command.text_clip_runs {
			glyphs := clip_run.glyph_run or { continue }
			font := glyphs.font()
			if font.is_invisible { continue }
			font_path := if glyphs.face() == .emoji {
				platform.emoji_font_path() or { continue }
			} else {
				font.font_path() or { continue }
			}
			run := cpuraster.CanvasGlyphRun{
				font_path:     font_path
				face_index:    font.face_index()
				font_size:     font.point_size
				glyphs:        glyphs.glyph_indices()
				positions:     glyphs.glyph_positions().map(f32(it))
				translation:   [f32(clip_run.glyph_translation_x), f32(clip_run.glyph_translation_y)]!
				baseline_snap: true
				retained:      true
				smoothing:     0
			}
			cpuraster.fill_canvas_glyphs_cached(mut cache, mut pixels, bounds.width, bounds.height,
				bounds.width * 4, 2, run, matrix, 0xff000000, none, 1, .src_over, [], none)
		}
	}
	app.portable_background_text_clip = PortableBackgroundTextClip{bounds, pixels}
}

struct PortableGradientGeometry {
	kind  string
	x     f64
	y     f64
	dx    f64
	dy    f64
	start f64
}

fn portable_gradient_geometry(gradient &layout.LinearGradient, tile painting.Rect) PortableGradientGeometry {
	if gradient.kind == 'conic' {
		return PortableGradientGeometry{
			kind:  'conic'
			x:     tile.x + tile.width * gradient.center_x
			y:     tile.y + tile.height * gradient.center_y
			start: gradient.start_degrees / 360
		}
	}
	if gradient.kind == 'radial' || gradient.radial {
		return PortableGradientGeometry{
			kind: 'radial'
			x:    tile.x + tile.width * gradient.center_x
			y:    tile.y + tile.height * gradient.center_y
			dx:   1 / math.max(0.000001, tile.width * gradient.radius_x)
			dy:   1 / math.max(0.000001, tile.height * gradient.radius_y)
		}
	}
	points := chromium_linear_gradient_points(*gradient, tile)
	dx := f64(points[2]) - f64(points[0])
	dy := f64(points[3]) - f64(points[1])
	length_squared := dx * dx + dy * dy
	absolute_x, absolute_y := if gradient.css_angle_degrees != none {
		tile.x, tile.y
	} else {
		0.0, 0.0
	}
	return PortableGradientGeometry{
		x:  absolute_x + f64(points[0])
		y:  absolute_y + f64(points[1])
		dx: if length_squared > 0 { dx / length_squared } else { 0.0 }
		dy: if length_squared > 0 { dy / length_squared } else { 0.0 }
	}
}

fn (geometry PortableGradientGeometry) position(point painting.Point) f64 {
	x := point.x - geometry.x
	y := point.y - geometry.y
	if geometry.kind == 'conic' {
		turn := math.atan2(x, -y) / (2 * math.pi) - geometry.start
		return turn - math.floor(turn)
	}
	dx := x * geometry.dx
	dy := y * geometry.dy
	if geometry.kind == 'radial' { return math.sqrt(dx * dx + dy * dy) }
	return dx + dy
}

struct PortableBackgroundTile {
	rect    painting.Rect
	clip    painting.Rect
	visible painting.Rect
}

fn (mut app BrowserApp) draw_portable_background(command &layout.PaintCommand, page_x f32,
	page_y f32) {
	scale := f64(app.ctx.scale)
	transform := portable_device_transform(command.transform, page_x, page_y, scale)
	inverse := transform.inverse() or { return }
	mut viewport := app.portable_device_viewport(page_y)
	if command.has_clip {
		viewport = viewport.intersection(painting.Rect{(command.clip_x + f64(page_x)) * scale, (command.clip_y + f64(page_y)) * scale, command.clip_width * scale, command.clip_height * scale})
	}
	has_text_clip := app.portable_background_text_clip != none
	mask := app.portable_background_text_clip or { PortableBackgroundTextClip{} }
	if has_text_clip {
		viewport = viewport.intersection(painting.Rect{f64(mask.bounds.x), f64(mask.bounds.y), f64(mask.bounds.width), f64(mask.bounds.height)})
	}
	if viewport.is_empty() { return }
	image := command.image()
	mut tiles := []PortableBackgroundTile{}
	mut painted := painting.Rect{}
	for tile in layout.resolved_background_gradient_tiles(*command) {
		mut clip := layout.background_gradient_tile_paint_rect(*command, tile)
		if command.gradient_background_layer {
			clip = clip.intersection(painting.Rect{image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height})
		}
		if recording_clip := command.recording_clip {
			clip = clip.intersection(painting.Rect{recording_clip.x, recording_clip.y, recording_clip.width, recording_clip.height})
		}
		if clip.is_empty() { continue }
		visible := transform.map_rect(clip).intersection(viewport)
		if visible.is_empty() { continue }
		tiles << PortableBackgroundTile{tile, clip, visible}
		painted = painted.united(visible)
	}
	if tiles.len == 0 { return }
	// One textured quad replaces the per-cell draw calls that could fill the
	// portable renderer's vertex buffer before subsequent content and chrome.
	bounds := portable_pixel_bounds(painted)
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	fill := if command.kind == 'fill_gradient' {
		css.Color{}
	} else {
		color := app.paint_colors.color(command.color, command.opacity)
		css.Color{color.r, color.g, color.b, color.a}
	}
	opacity := if command.kind == 'fill_gradient' { command.opacity } else { 1.0 }
	for tile in tiles {
		geometry := if gradient := command.gradient {
			portable_gradient_geometry(gradient, tile.rect)
		} else {
			PortableGradientGeometry{}
		}
		visible := portable_pixel_bounds(tile.visible)
		for y in visible.y .. visible.bottom() {
			for x in visible.x .. visible.right() {
				coverage := if has_text_clip { mask.alpha_at(x, y) } else { u8(255) }
				if coverage == 0 { continue }
				point := inverse.map_point(painting.Point{f64(x) + 0.5, f64(y) + 0.5})
				if !tile.clip.contains(point) || (!command.gradient_background_layer
					&& command.points.len > 0 && !point_in_paint_polygon(point.x, point.y, command.points)) {
					continue
				}
				color := if gradient := command.gradient {
					layout.gradient_color_at(*gradient, geometry.position(point))
				} else {
					fill
				}
				offset := ((y - bounds.y) * bounds.width + x - bounds.x) * 4
				pixels[offset] = color.r
				pixels[offset + 1] = color.g
				pixels[offset + 2] = color.b
				pixels[offset + 3] = u8(clamp(f64(color.a) * opacity * f64(coverage) / 255, 0, 255) + 0.5)
			}
		}
	}
	app.draw_portable_raster_image(f32(f64(bounds.x) / scale), f32(f64(bounds.y) / scale),
		bounds.width, bounds.height, pixels)
}
