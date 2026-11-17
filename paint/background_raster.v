module main

import css
import gg
import layout
import math
import os
import painting

const disable_portable_gradient_ramp = os.getenv('VOX_DISABLE_PORTABLE_GRADIENT_RAMP') != ''
const portable_gradient_ramp_diagnostics = os.getenv('VOX_PORTABLE_GRADIENT_RAMP_DIAGNOSTICS') == '1'

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

fn (mut app BrowserApp) draw_raster_background(command &layout.PaintCommand, source_tiles []painting.Rect,
	page_x f32, page_y f32) {
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
	for tile in source_tiles {
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
	if !app.ctx.native_rendering && !disable_portable_gradient_ramp && !has_text_clip
		&& tiles.len == 1 && (command.gradient_background_layer || command.points.len == 0) {
		if gradient := command.gradient {
			if ramp := background_gradient_ramp(gradient, tiles[0], bounds, inverse, command.opacity) {
				if portable_gradient_ramp_diagnostics {
					eprintln('VOX_GRADIENT_RAMP texture=${ramp.width}x${ramp.height} destination=${bounds.width}x${bounds.height}')
				}
				app.draw_portable_raster_texture(gg.Rect{f32(f64(bounds.x) / scale), f32(f64(bounds.y) / scale), f32(f64(bounds.width) / scale), f32(f64(bounds.height) / scale)}, ramp.width, ramp.height, ramp.pixels)
				return
			}
		}
	}
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
	x := f32(f64(bounds.x) / scale)
	y := f32(f64(bounds.y) / scale)
	$if macos {
		if app.ctx.native_rendering {
			bitmap := &gg.Image{
				width:       bounds.width
				height:      bounds.height
				nr_channels: 6
				ok:          true
				data:        pixels.data
			}
			C.native_draw_image_part(bitmap, x, y, f32(f64(bounds.width) / scale),
				f32(f64(bounds.height) / scale), 0, 0, f32(bounds.width), f32(bounds.height),
				f32(app.ctx.height), 1)
			return
		}
	}
	app.draw_portable_raster_image(x, y,
		bounds.width, bounds.height, pixels)
}

struct BackgroundGradientRamp {
	width  int
	height int
	pixels []u8
}

fn background_gradient_ramp(gradient &layout.LinearGradient, tile PortableBackgroundTile,
	bounds painting.IntRect, inverse painting.Affine, opacity f64) ?BackgroundGradientRamp {
	if inverse.b != 0 || inverse.c != 0 || gradient.kind == 'conic'
		|| gradient.kind == 'radial' || gradient.radial {
		return none
	}
	geometry := portable_gradient_geometry(gradient, tile.rect)
	if geometry.dx != 0 && geometry.dy != 0 { return none }
	horizontal := geometry.dy == 0
	if (horizontal && bounds.height <= 1) || (!horizontal && bounds.width <= 1) { return none }
	first := painting.Point{f64(bounds.x) + 0.5, f64(bounds.y) + 0.5}
	last := painting.Point{f64(bounds.right()) - 0.5, f64(bounds.bottom()) - 0.5}
	// The rectangular tile must cover every device pixel center in the quad.
	if !tile.clip.contains(inverse.map_point(first)) || !tile.clip.contains(inverse.map_point(last)) {
		return none
	}
	length := if horizontal { bounds.width } else { bounds.height }
	mut pixels := []u8{len: length * 4}
	for index in 0 .. length {
		point := if horizontal {
			painting.Point{first.x + f64(index), first.y}
		} else {
			painting.Point{first.x, first.y + f64(index)}
		}
		color := layout.gradient_color_at(*gradient, geometry.position(inverse.map_point(point)))
		offset := index * 4
		pixels[offset] = color.r
		pixels[offset + 1] = color.g
		pixels[offset + 2] = color.b
		pixels[offset + 3] = u8(clamp(f64(color.a) * opacity, 0, 255) + 0.5)
	}
	return BackgroundGradientRamp{
		width:  if horizontal { length } else { 1 }
		height: if horizontal { 1 } else { length }
		pixels: pixels
	}
}
