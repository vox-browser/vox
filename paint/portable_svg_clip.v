module main

import cpuraster
import layout
import math
import os
import painting

const disable_portable_svg_clip = os.getenv('VOX_DISABLE_PORTABLE_SVG_CLIP') == '1'
const portable_svg_clip_diagnostics = os.getenv('VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS') == '1'

fn portable_svg_clip_group_end(commands []layout.PaintCommand, start int, mask layout.PaintClip) ?int {
	if start + 2 >= commands.len || !portable_svg_group_clip_supported(&commands[start]) { return none }
	first := &commands[start + 1]
	limit := math.min(commands.len, start + portable_svg_group_max_paths + 2)
	for index in start + 1 .. limit {
		command := &commands[index]
		if command.kind == 'end_svg_mask_layer' {
			closing := command.mask_clip()
			if index > start + 1 && closing.is_svg_mask && !closing.is_svg_content_mask
				&& closing.cache_key == mask.cache_key && closing.scope_id == mask.scope_id
				&& closing.rect == mask.rect && closing.transform == mask.transform {
				return index
			}
			return none
		}
		if !portable_svg_group_fill_supported(command, first, 1) { return none }
	}
	return none
}

fn (mut app BrowserApp) draw_portable_svg_clip_group(commands []layout.PaintCommand,
	start int, page_x f32, page_y f32, outer_viewport ?painting.Rect) int {
	if disable_portable_svg_clip || !app.portable_svg_group_allowed() { return start }
	mask := commands[start].mask_clip()
	if !mask.is_svg_mask || mask.is_svg_content_mask || mask.path_components.len > 64 { return start }
	end := portable_svg_clip_group_end(commands, start, mask) or { return start }
	scale := f64(app.ctx.scale)
	mut viewport := outer_viewport or { app.portable_device_viewport(page_y) }
	mut direct_crop := false
	if rect := svg_background_rectangular_clip(mask) {
		device := portable_device_transform([f64(1), 0, 0, 1, 0, 0]!, page_x, page_y, scale).map_rect(rect)
		viewport = viewport.intersection(device)
		direct_crop = [device.x, device.y, device.right(), device.bottom()]!.all(it == math.floor(it))
	} else {
		local := painting.Rect{mask.rect.x, mask.rect.y, mask.rect.width, mask.rect.height}
		transform := portable_device_transform(mask.transform, page_x, page_y, scale)
		viewport = viewport.intersection(transform.map_rect(local))
	}
	mut image := app.raster_portable_svg_group(commands[start + 1..end], viewport, page_x, page_y,
		1) or { return start }
	if image.bounds.is_empty() { return end + 1 }
	if !direct_crop && !apply_portable_svg_clip(mut image, mask.path_components, page_x, page_y, scale) {
		return start
	}
	app.draw_portable_svg_group_image(image, 255)
	if portable_svg_clip_diagnostics {
		eprintln('VOX_SVG_CLIP crop=${direct_crop} components=${mask.path_components.len} paths=${image.paths} texture=${image.bounds.width}x${image.bounds.height}')
	}
	return end + 1
}

fn apply_portable_svg_clip(mut image PortableSVGGroupImage, components []layout.PaintPath,
	page_x f32, page_y f32, scale f64) bool {
	bounds := image.bounds
	pitch := bounds.width * 4
	mut coverage := []u8{len: pitch * bounds.height}
	for part in components {
		if part.path_data.len < layout.compatibility_clip_path_segment_stride { continue }
		path := cpuraster.canvas_path(part.path_data, part.path_even_odd)
		transform := portable_device_transform(part.transform, page_x, page_y, scale)
		if !cpuraster.fill_canvas_path(mut coverage, bounds.width, bounds.height, pitch, 2,
			path, portable_svg_surface_matrix(transform, bounds), 0xffffffff, none, 1,
			.src_over, 0, [], none) {
			return false
		}
	}
	// Components form one coverage mask over the resolved SVG source.
	for alpha := 3; alpha < coverage.len; alpha += 4 {
		image.pixels[alpha] = u8((u32(image.pixels[alpha]) * u32(coverage[alpha]) + 127) / 255)
	}
	return true
}
