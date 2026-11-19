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

fn portable_svg_group_clip_supported(command &layout.PaintCommand) bool {
	if !chromium_shared_recording_clips_supported(command) || command.clip_outs.len > 0
		|| command.recording_clip != none {
		return false
	}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.transform[1] != 0 || clip.transform[2] != 0 || clip.corner_radii != layout.BoxRadii{} {
				return false
			}
		}
	}
	return true
}

fn portable_svg_group_fill_supported(command &layout.PaintCommand, first &layout.PaintCommand,
	group_opacity f64) bool {
	data := command.svg_data
	if command.kind != 'draw_svg_path' || data == unsafe { nil }
		|| data.path_data.len < layout.compatibility_clip_path_segment_stride || data.fill_pattern != none
		|| (command.stroke_width > 0 && (command.stroke_color != '' || data.stroke_pattern != none))
		|| command.blur != 0 || command.outer_shadow || command.scrollbar_axis != ''
		|| f32(command.group_opacity) != f32(group_opacity)
		|| command.has_clip != first.has_clip || command.clip_x != first.clip_x
		|| command.clip_y != first.clip_y || command.clip_width != first.clip_width
		|| command.clip_height != first.clip_height || !portable_svg_group_clip_supported(command) {
		return false
	}
	if gradients := data.svg_gradient_data {
		if command.stroke_width > 0 && (gradients.stroke_linear_gradient != none
			|| gradients.stroke_radial_gradient != none) {
			return false
		}
		if gradients.fill_linear_gradient != none || gradients.fill_radial_gradient != none {
			return true
		}
	}
	return command.color != ''
}

struct PortableSVGGroupPath {
	path      cpuraster.Path
	transform painting.Affine
	color     u32
	style     ?cpuraster.CanvasPaintStyle
	opacity   f32
}

struct PortableSVGGroupImage {
	bounds painting.IntRect
	paths  int
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
	mut paths := []PortableSVGGroupPath{cap: commands.len}
	for index in 0 .. commands.len {
		command := &commands[index]
		data := command.svg_data
		path := cpuraster.canvas_path(data.path_data, data.fill_even_odd)
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, scale)
		bounds := portable_svg_path_bounds(path, transform, clip) or { return none }
		if bounds.is_empty() { continue }
		// Opacity scopes already folded their alpha into the recorded leaves.
		// Restore the fill alpha before compositing the members.
		fill_alpha := command.opacity / group_opacity * data.fill_opacity
		mut style := ?cpuraster.CanvasPaintStyle(none)
		mut color := u32(0xff000000)
		mut opacity := f32(1)
		if gradients := data.svg_gradient_data {
			if gradients.fill_linear_gradient != none || gradients.fill_radial_gradient != none {
				opacity = f32(clamp(fill_alpha, 0, 1))
				if opacity == 0 { continue }
				gradient := portable_svg_visible_gradient(command, false) or { return none }
				style = cpuraster.CanvasPaintStyle(gradient)
			}
		}
		if style == none {
			solid := app.paint_colors.color_with_retained(command.color, fill_alpha,
				command.retained_svg_fill_color())
			if solid.a == 0 { continue }
			color = portable_svg_argb(solid)
		}
		ink = ink.united(bounds)
		path_bounds := portable_pixel_bounds(bounds)
		path_pixels += path_bounds.width * path_bounds.height
		paths << PortableSVGGroupPath{path, transform, color, style, opacity}
	}
	if paths.len == 0 { return PortableSVGGroupImage{} }
	bounds := portable_pixel_bounds(ink)
	// Leave widely separated paths on the leaf renderer instead of uploading
	// a large area of transparent pixels between them.
	pixel_count := bounds.width * bounds.height
	if pixel_count > portable_svg_group_max_pixels || pixel_count > path_pixels + 16384 { return none }
	pitch := bounds.width * 4
	mut surface := []u8{len: pitch * bounds.height}
	for path in paths {
		if !cpuraster.fill_canvas_path(mut surface, bounds.width, bounds.height, pitch, 2,
			path.path, portable_svg_surface_matrix(path.transform, bounds), path.color, path.style, path.opacity,
			.src_over, 0, [], none) {
			return none
		}
	}
	mut pixels := []u8{len: surface.len}
	if !cpuraster.read_pixels(surface, bounds.width, bounds.height, pitch, 2, mut pixels,
		bounds.width, bounds.height, pitch, 0, 0) {
		return none
	}
	return PortableSVGGroupImage{bounds: bounds, paths: paths.len, pixels: pixels}
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
