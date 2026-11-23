module main

import cpuraster
import gg
import layout
import math
import os
import painting
import platform

const disable_portable_rounded_image_clip = os.getenv('VOX_DISABLE_PORTABLE_ROUNDED_IMAGE_CLIP') == '1'
const disable_portable_image_clip_cache = os.getenv('VOX_DISABLE_PORTABLE_IMAGE_CLIP_CACHE') == '1'

struct PortableRoundedImageClipKey {
	shape cpuraster.RoundedClipGeometry
	width int
	height int
}

struct PortableRoundedImageClipCache {
mut:
	key PortableRoundedImageClipKey
	count int
	spans [128]cpuraster.ClipCoverageRect
}

fn (mut app BrowserApp) portable_image_clip_spans(key PortableRoundedImageClipKey,
	limit int) ?[]cpuraster.ClipCoverageRect {
	mut cache := app.portable_rounded_image_clip_cache
	if !disable_portable_image_clip_cache && cache != unsafe { nil } && cache.key == key {
		if cache.count > limit { return none }
		return cache.spans[..cache.count]
	}
	clip := cpuraster.canvas_raster_clip(key.width, key.height, [key.shape.path()])
	spans := clip.coverage_rects(limit)?
	if !disable_portable_image_clip_cache && spans.len <= 128 {
		if cache == unsafe { nil } {
			persistent := platform.enter_persistent()
			cache = &PortableRoundedImageClipCache{}
			app.portable_rounded_image_clip_cache = cache
			platform.leave_persistent(persistent)
		}
		cache.key = key
		cache.count = spans.len
		for index, span in spans { cache.spans[index] = span }
	}
	return spans
}

fn (mut app BrowserApp) draw_portable_rounded_image(command &layout.PaintCommand, config gg.DrawImageConfig,
	result painting.ImagePaintResult, page_x f32, page_y f32, scroll_y f64) bool {
	if disable_portable_rounded_image_clip { return false }
	data := replaced_image_gpu_clip_data(command, result.bitmap.clip_rect, result.clip_radii, -1)
	return app.draw_portable_rounded_bitmap(command, config, result.bitmap, data, none,
		page_x, page_y, scroll_y)
}

fn (mut app BrowserApp) draw_portable_rounded_bitmap(command &layout.PaintCommand, config gg.DrawImageConfig,
	geometry painting.DrawScaledDecodedImageFrame, data [12]f32, stream ?PortableBitmapStream,
	page_x f32, page_y f32, scroll_y f64) bool {
	radii := [data[4], data[5], data[6], data[7], data[8], data[9], data[10], data[11]]!
	if radii[..].all(it <= 0) { return false }
	width, height := if live := stream { live.bitmap.width, live.bitmap.height } else { config.img.width, config.img.height }
	replay := replaced_image_replay_rects(geometry.destination, geometry.clip_rect, width,
		height, true) or { return true }
	draw := replay.destination
	scale := f64(app.ctx.scale)
	transform := portable_device_transform(command.transform, page_x, page_y - f32(scroll_y), scale)
	visible := transform.map_rect(painting.Rect{f64(draw.x), f64(draw.y), f64(draw.width), f64(draw.height)})
		.intersection(app.portable_device_viewport(page_y))
	bounds := portable_pixel_bounds(visible)
	if bounds.is_empty() { return true }
	// Bound work by the visible extent. Texture coordinates still refer to the
	// full object-fit crop and are independent of viewport cropping.
	if transform.a > 0 && transform.d > 0 && transform.b == 0 && transform.c == 0 {
		origin := transform.map_point(painting.Point{f64(data[0]), f64(data[1])})
		// Use the clip's local origin so integer movement and identical adjacent
		// images can share coverage. Fractional offsets and crops stay in the key.
		shape := cpuraster.RoundedClipGeometry{
			rect: cpuraster.Rect{0, 0, data[2], data[3]}
			radii: radii
			transform: cpuraster.Matrix{f32(transform.a), 0, 0, f32(transform.d),
				f32(origin.x - f64(bounds.x)), f32(origin.y - f64(bounds.y))}
		}
		if app.draw_portable_image_clip_spans(config, bounds, shape, stream) { return true }
	}
	// Rasterize directly from the retained bitmap when the source is streamed.
	source := if live := stream {
		retained := live.bitmap
		cpuraster.CanvasBitmap{
			pixels: retained.data
			width: retained.width
			height: retained.height
			pitch: retained.pitch
			premultiplied: retained.alpha_type in [u8(0), 2]
		}
	} else {
		image := config.img
		if image.data == unsafe { nil } || image.nr_channels != 4 { return false }
		pitch := image.width * 4
		cpuraster.CanvasBitmap{
			pixels: unsafe { (&u8(image.data)).vbytes(pitch * image.height) }
			width: image.width
			height: image.height
			pitch: pitch
		}
	}
	matrix := portable_svg_surface_matrix(transform, bounds)
	path := cpuraster.rounded_rect(cpuraster.Rect{data[0], data[1], data[0] + data[2],
		data[1] + data[3]}, radii).clip_path(cpuraster.Matrix{matrix[0], matrix[1],
		matrix[2], matrix[3], matrix[4], matrix[5]})
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	if !cpuraster.draw_canvas_image(mut pixels, bounds.width, bounds.height, bounds.width * 4, 2,
		matrix, source, replay.source,
		[f32(draw.x), f32(draw.y), f32(draw.width), f32(draw.height)]!,
		geometry.scaling != .nearest_neighbor, 1, .src_over, [path]) {
		return false
	}
	cpuraster.unpremultiply_rgba_in_place(mut pixels)
	app.draw_portable_raster_texture_with_alpha(gg.Rect{f32(f64(bounds.x) / scale),
		f32(f64(bounds.y) / scale), f32(f64(bounds.width) / scale), f32(f64(bounds.height) / scale)},
		bounds.width, bounds.height, pixels, config.color.a)
	return true
}

fn (mut app BrowserApp) draw_portable_image_clip_spans(image_config gg.DrawImageConfig, bounds painting.IntRect,
	shape cpuraster.RoundedClipGeometry, stream ?PortableBitmapStream) bool {
	renderer := app.ctx.r
	if renderer == unsafe { nil } || (stream == none && !image_config.img.simg_ok) { return false }
	// Limit the extra geometry in GG's shared frame queue. Large clips can use
	// the viewport-sized raster fallback without exhausting the vertex buffer.
	limit := math.min(2048, (32768 - renderer.num_vertices()) / 6)
	spans := app.portable_image_clip_spans(PortableRoundedImageClipKey{shape, bounds.width, bounds.height},
		limit) or { return false }
	if spans.len == 0 { return true }
	mut config := image_config
	if live := stream {
		config.img = app.portable_bitmap_texture(live)
	}
	image := config.img
	if spans.len == 1 && spans[0] == cpuraster.ClipCoverageRect{
		cpuraster.IRect{0, 0, bounds.width, bounds.height}, 255} {
		app.ctx.draw_image_with_config(config)
		return true
	}
	rect := config.img_rect
	scale := app.ctx.scale
	left, top := rect.x * scale, rect.y * scale
	right, bottom := (rect.x + rect.width) * scale, (rect.y + rect.height) * scale
	if right <= left || bottom <= top { return true }
	part := config.part_rect
	u0, v0 := part.x / image.width, part.y / image.height
	du := ((part.x + part.width) / image.width - u0) / (right - left)
	dv := ((part.y + part.height) / image.height - v0) / (bottom - top)
	image_id := int(image.simg.id)
	if image.data != unsafe { nil } && !renderer.is_image_registered(image_id) {
		filter := if image.texture_filter == .linear { 1 } else { 0 }
		renderer.register_image(image_id, image.data, image.width, image.height, 4, filter)
	}
	renderer.load_pipeline(app.ctx.pipeline.alpha)
	renderer.enable_texture()
	renderer.texture(image.simg, image.ssmp)
	renderer.begin_quads()
	for span in spans {
		x1 := math.max(left, f32(bounds.x + span.rect.left))
		y1 := math.max(top, f32(bounds.y + span.rect.top))
		x2 := math.min(right, f32(bounds.x + span.rect.right))
		y2 := math.min(bottom, f32(bounds.y + span.rect.bottom))
		if x1 >= x2 || y1 >= y2 { continue }
		// Map each rectangle through the original unrounded image quad so the
		// source crop, filter and mipmap choice stay independent of the clip.
		u1, v1 := u0 + (x1 - left) * du, v0 + (y1 - top) * dv
		u2, v2 := u0 + (x2 - left) * du, v0 + (y2 - top) * dv
		a := u8((int(config.color.a) * int(span.alpha) + 127) / 255)
		renderer.c4b(255, 255, 255, a)
		renderer.v3f_t2f(x1, y1, 0, u1, v1)
		renderer.v3f_t2f(x2, y1, 0, u2, v1)
		renderer.v3f_t2f(x2, y2, 0, u2, v2)
		renderer.v3f_t2f(x1, y2, 0, u1, v2)
	}
	renderer.end()
	renderer.disable_texture()
	return true
}
