module main

import cpuraster
import gg
import layout
import math
import painting

const portable_svg_group_max_paths = 128
const portable_svg_group_max_pixels = 4 * 1024 * 1024

fn (app &BrowserApp) portable_svg_group_allowed() bool {
	return !app.ctx.native_rendering && app.page_zoom == 1 && app.paint_effect_depth == 0
		&& app.paint_svg_mask_depth == 0 && app.portable_background_text_clip == none
}

fn portable_svg_group_clip_supported(command &layout.PaintCommand, mask ?&layout.PaintClip) bool {
	if !chromium_shared_recording_clips_supported(command) || command.clip_outs.len > 0
		|| command.recording_clip != none {
		return false
	}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.corner_radii != layout.BoxRadii{} || clip.transform[1] != 0 || clip.transform[2] != 0 {
				region := mask or { return false }
				if !region.is_svg_content_mask { return false }
			}
		}
	}
	return true
}

@[inline]
fn portable_svg_group_has_stroke(command &layout.PaintCommand) bool {
	if !(command.stroke_width > 0) { return false }
	if command.stroke_color != '' { return true }
	data := command.svg_data
	if data != unsafe { nil } {
		if data.stroke_pattern != none { return true }
		if gradients := data.svg_gradient_data {
			return gradients.stroke_linear_gradient != none || gradients.stroke_radial_gradient != none
		}
	}
	return false
}

fn portable_svg_group_path_supported(command &layout.PaintCommand, first &layout.PaintCommand,
	group_opacity f64, mask ?&layout.PaintClip) bool {
	data := command.svg_data
	if command.kind != 'draw_svg_path' || data == unsafe { nil }
		|| data.path_data.len < layout.compatibility_clip_path_segment_stride
		|| command.blur != 0 || command.outer_shadow || command.scrollbar_axis != ''
		|| f32(command.group_opacity) != f32(group_opacity)
		|| command.has_clip != first.has_clip || command.clip_x != first.clip_x
		|| command.clip_y != first.clip_y || command.clip_width != first.clip_width
		|| command.clip_height != first.clip_height || !portable_svg_group_clip_supported(command, mask) {
		return false
	}
	if command.color != '' || data.fill_pattern != none || portable_svg_group_has_stroke(command) {
		return true
	}
	if gradients := data.svg_gradient_data {
		return gradients.fill_linear_gradient != none || gradients.fill_radial_gradient != none
	}
	return false
}

struct PortableSVGGroupPaint {
	path         cpuraster.Path
	transform    painting.Affine
	color        u32
	gradient     ?cpuraster.CanvasGradient
	pattern      ?&painting.SVGPatternPaintStyle
	opacity      f32
	stroke_data  &layout.PaintSVGPathData = unsafe { nil }
	stroke_width f32
	stroke_miter f32
}

struct PortableSVGGroupImage {
	bounds     painting.IntRect
	paths      int
	incomplete bool
mut:
	pixels []u8
}

struct PortableSVGGroupRecording {
	document u64
	revision u64
	viewport painting.Rect
}

struct PortableSVGGroupKey {
	recording  PortableSVGGroupRecording
	start      int
	viewport   painting.Rect
	page_x     f32
	page_y     f32
	scale      f32
}

struct PortableSVGGroupTexture {
	key    PortableSVGGroupKey
	bounds painting.IntRect
}

struct PortableSVGGroupVariant {
	image   PortableRasterImage
	texture PortableSVGGroupTexture
}

struct PortableSVGGroupSlot {
mut:
	active    PortableSVGGroupTexture
	alternate PortableSVGGroupVariant
}

fn (app &BrowserApp) portable_svg_group_key(commands []layout.PaintCommand, start int,
	viewport painting.Rect, page_x f32, page_y f32) PortableSVGGroupKey {
	// Nested recordings use projected copies with their own transforms.
	if disable_portable_svg_raster_cache || commands.data != app.paint_commands.data
		|| app.portable_raster_image_index >= portable_svg_raster_slots {
		return PortableSVGGroupKey{}
	}
	// Root scrolling rebuilds lowered commands. The content revision covers
	// their paint, and the recorded viewport fixes the placement of sticky
	// and fixed content at each offset.
	recording := if portable_svg_viewport_reuse {
		app.portable_svg_group_recording
	} else {
		PortableSVGGroupRecording{revision: app.paint_generation}
	}
	return PortableSVGGroupKey{recording, start, viewport, page_x, page_y, app.ctx.scale}
}

fn (mut app BrowserApp) draw_portable_svg_pattern_path(source &layout.PaintCommand,
	command &layout.PaintCommand, page_x f32, page_y f32) bool {
	// Scope handlers own mask coverage and opacity. A declined scope must
	// not retain a leaf texture as if it had been drawn on its own.
	if app.paint_svg_mask_depth != 0 || app.paint_effect_depth != 0
		|| app.portable_background_text_clip != none
		|| !portable_svg_group_path_supported(command, command, 1, none) {
		return false
	}
	viewport := app.portable_device_viewport(page_y)
	mut key := PortableSVGGroupKey{}
	// Only adopted root commands have a stable index across frames. Nested
	// and zoomed commands use projected copies with different transforms.
	if app.draw_command_depth == 1 && app.page_zoom == 1 {
		base := u64(app.paint_commands.data)
		address := u64(voidptr(source))
		stride := sizeof(layout.PaintCommand)
		if address >= base && address - base < u64(app.paint_commands.len) * stride {
			key = app.portable_svg_group_key(app.paint_commands, int((address - base) / stride),
				viewport, page_x, page_y)
		}
	}
	if app.draw_cached_portable_svg_group(key, 255) { return true }
	image := app.raster_portable_svg_group([*command], viewport, page_x, page_y, 1) or { return false }
	if !image.bounds.is_empty() {
		app.draw_portable_svg_group_image(image, 255, if image.incomplete { PortableSVGGroupKey{} } else { key })
	}
	return true
}

fn (mut app BrowserApp) draw_cached_portable_svg_group(key PortableSVGGroupKey, alpha u8) bool {
	index := app.portable_raster_image_index
	if key.recording.revision == 0 || index >= app.portable_raster_images.len { return false }
	mut group := &app.portable_svg_group_textures[index]
	mut detail := ''
	if group.active.key != key {
		alternate := group.alternate
		if alternate.texture.key != key { return false }
		group.alternate = PortableSVGGroupVariant{app.portable_raster_images[index], group.active}
		group.active = alternate.texture
		app.portable_raster_images[index] = alternate.image
		detail = ' variant=hit'
	}
	app.ctx.draw_image_with_config(img_id: app.portable_raster_images[index].image_id,
		img_rect: app.portable_svg_texture_destination(group.active.bounds),
		color: gg.Color{255, 255, 255, alpha})
	app.portable_raster_image_index++
	if portable_svg_raster_diagnostics {
		eprintln('VOX_SVG_GROUP cache=hit start=${key.start}${detail}')
	}
	return true
}

fn (mut app BrowserApp) raster_portable_svg_group(commands []layout.PaintCommand,
	viewport painting.Rect, page_x f32, page_y f32, group_opacity f64) ?PortableSVGGroupImage {
	scale := f64(app.ctx.scale)
	first := &commands[0]
	clip := if first.has_clip {
		viewport.intersection(portable_svg_device_clip(layout.LayoutRect{first.clip_x, first.clip_y,
			first.clip_width, first.clip_height}, page_x, page_y, scale))
	} else {
		viewport
	}
	if clip.is_empty() { return PortableSVGGroupImage{} }
	mut ink := painting.Rect{}
	mut path_pixels := 0
	mut paints := []PortableSVGGroupPaint{cap: commands.len}
	mut visible_paths := 0
	for index in 0 .. commands.len {
		command := &commands[index]
		data := command.svg_data
		path := cpuraster.canvas_path(data.path_data, data.fill_even_odd)
		local := path.bounds() or { return none }
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, scale)
		first_paint := paints.len
		// Opacity scopes already folded their alpha into the recorded leaves.
		// Restore each leaf's alpha before compositing the members.
		leaf_alpha := command.opacity / group_opacity
		fill_bounds := portable_svg_device_bounds(local, transform, clip)
		if !fill_bounds.is_empty() {
			fill_alpha := leaf_alpha * data.fill_opacity
			mut gradient := ?cpuraster.CanvasGradient(none)
			mut color := u32(0)
			mut opacity := f32(1)
			if data.fill_pattern != none {
				opacity = f32(clamp(fill_alpha, 0, 1))
				color = 0xff000000
			} else if gradients := data.svg_gradient_data {
				if gradients.fill_linear_gradient != none || gradients.fill_radial_gradient != none {
					opacity = f32(clamp(fill_alpha, 0, 1))
					if opacity != 0 {
						gradient = portable_svg_visible_gradient(command, false) or { return none }
						color = 0xff000000
					}
				}
			}
			if gradient == none && data.fill_pattern == none && command.color != '' {
				solid := app.paint_colors.color_with_retained(command.color, fill_alpha,
					command.retained_svg_fill_color())
				color = portable_svg_argb(solid)
			}
			if color >> 24 != 0 && opacity != 0 {
				ink = ink.united(fill_bounds)
				pixel_bounds := portable_pixel_bounds(fill_bounds)
				path_pixels += pixel_bounds.width * pixel_bounds.height
				paints << PortableSVGGroupPaint{
					path: path
					transform: transform
					color: color
					gradient: gradient
					pattern: data.fill_pattern
					opacity: opacity
				}
			}
		}
		if portable_svg_group_has_stroke(command) {
			width := f32(command.stroke_width)
			miter := f32(if data.stroke_miterlimit > 1 { data.stroke_miterlimit } else { 1.0 })
			if !(width > 0) || !math.is_finite(f64(width)) || !math.is_finite(f64(miter)) {
				return none
			}
			stroke_alpha := leaf_alpha * data.stroke_opacity
			mut opacity := f32(clamp(stroke_alpha, 0, 1))
			mut color := u32(0xff000000)
			mut gradient := ?cpuraster.CanvasGradient(none)
			stroke_bounds := portable_svg_stroke_bounds(data, local, transform, clip, width, miter)
			if opacity != 0 && !stroke_bounds.is_empty() {
				if data.stroke_pattern == none {
					if command.stroke_color == '' {
						gradient = portable_svg_visible_gradient(command, true) or { return none }
					} else {
						solid := app.paint_colors.color_with_retained(command.stroke_color, stroke_alpha,
							command.retained_svg_stroke_color())
						color = portable_svg_argb(solid)
						opacity = 1
					}
				}
				if color >> 24 != 0 {
					ink = ink.united(painting.Rect{f64(stroke_bounds.x), f64(stroke_bounds.y),
						f64(stroke_bounds.width), f64(stroke_bounds.height)})
					path_pixels += stroke_bounds.width * stroke_bounds.height
					paints << PortableSVGGroupPaint{
						path: cpuraster.Path{...path, fill_type: .winding}
						transform: transform
						color: color
						gradient: gradient
						pattern: data.stroke_pattern
						opacity: opacity
						stroke_data: data
						stroke_width: width
						stroke_miter: miter
					}
					if data.stroke_first && paints.len == first_paint + 2 {
						paints[first_paint], paints[first_paint + 1] = paints[first_paint + 1], paints[first_paint]
					}
				}
			}
		}
		if paints.len > first_paint { visible_paths++ }
	}
	if paints.len == 0 { return PortableSVGGroupImage{} }
	bounds := portable_pixel_bounds(ink)
	// Leave widely separated paths on the leaf renderer instead of uploading
	// a large area of transparent pixels between them.
	pixel_count := bounds.width * bounds.height
	if pixel_count > portable_svg_group_max_pixels || pixel_count > path_pixels + 16384 { return none }
	pitch := bounds.width * 4
	mut surface := []u8{len: pitch * bounds.height}
	mut incomplete := false
	mut tile_budget := PortableSVGMaskTileBudget{}
	for paint in paints {
		matrix := portable_svg_surface_matrix(paint.transform, bounds)
		mut style := ?cpuraster.CanvasPaintStyle(none)
		if gradient := paint.gradient { style = cpuraster.CanvasPaintStyle(gradient) }
		if pattern := paint.pattern {
			if !portable_svg_mask_pattern_supported(pattern) { return none }
			// Preserve tile RGB for the foreground paint.
			tile := app.raster_svg_mask_pattern(pattern, matrix, true, unsafe { nil }, mut tile_budget)?
			style = cpuraster.CanvasPaintStyle(tile.pattern)
			incomplete = incomplete || !tile.cacheable
		}
		drawn := if paint.stroke_data != unsafe { nil } {
			raster_portable_svg_stroke(mut surface, bounds, paint.path, matrix, paint.stroke_data,
				paint.color, style, paint.opacity, paint.stroke_width, paint.stroke_miter)
		} else {
			cpuraster.fill_canvas_path(mut surface, bounds.width, bounds.height, pitch, 2,
				paint.path, matrix, paint.color, style, paint.opacity, .src_over, 0, [], none)
		}
		if !drawn {
			return none
		}
	}
	cpuraster.unpremultiply_rgba_in_place(mut surface)
	return PortableSVGGroupImage{bounds: bounds, paths: visible_paths, incomplete: incomplete, pixels: surface}
}

fn (mut app BrowserApp) draw_portable_svg_group_image(image &PortableSVGGroupImage, alpha u8,
	key PortableSVGGroupKey) {
	bounds := image.bounds
	index := app.portable_raster_image_index
	mut alternate := PortableSVGGroupVariant{}
	if portable_svg_viewport_reuse && key.recording.revision != 0
		&& index < app.portable_raster_images.len
		&& bounds.width * bounds.height <= portable_svg_clip_variant_pixels {
		active := app.portable_svg_group_textures[index].active
		slot := app.portable_raster_images[index]
		if active.key.recording.document == key.recording.document
			&& active.key.recording.revision == key.recording.revision && active.key.start == key.start
			&& active.key.scale == key.scale
			&& slot.width * slot.height <= portable_svg_clip_variant_pixels {
			// Keep the exact previous placement. The new raster's origin
			// can change gradient rounding, even at equal texture sizes.
			alternate = PortableSVGGroupVariant{slot, active}
			app.portable_raster_images[index] = PortableRasterImage{image_id: -1}
		}
	}
	app.draw_portable_raster_texture_with_alpha(app.portable_svg_texture_destination(bounds),
		bounds.width, bounds.height, image.pixels, alpha)
	if key.recording.revision != 0 {
		app.portable_svg_group_textures[index] = PortableSVGGroupSlot{
			active: PortableSVGGroupTexture{key, bounds}
			alternate: alternate
		}
		if portable_svg_raster_diagnostics {
			eprintln('VOX_SVG_GROUP cache=miss start=${key.start}')
		}
	}
}

fn portable_svg_device_clip(clip layout.LayoutRect, page_x f32, page_y f32, scale f64) painting.Rect {
	if clip.width <= 0 || clip.height <= 0 { return painting.Rect{} }
	left := math.floor((clip.x + f64(page_x)) * scale)
	top := math.floor((clip.y + f64(page_y)) * scale)
	right := math.ceil((clip.x + clip.width + f64(page_x)) * scale)
	bottom := math.ceil((clip.y + clip.height + f64(page_y)) * scale)
	return painting.Rect{left, top, right - left, bottom - top}
}
