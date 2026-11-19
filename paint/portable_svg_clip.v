module main

import cpuraster
import layout
import math
import os
import painting

const disable_portable_svg_clip = os.getenv('VOX_DISABLE_PORTABLE_SVG_CLIP') == '1'
const portable_svg_clip_diagnostics = os.getenv('VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS') == '1'

fn portable_svg_mask_group_end(commands []layout.PaintCommand, start int, mask layout.PaintClip) ?int {
	if mask.is_svg_content_mask {
		if disable_portable_svg_mask || !portable_svg_content_mask_supported(&mask) { return none }
	} else if disable_portable_svg_clip || !mask.is_svg_mask || mask.path_components.len > 64 {
		return none
	}
	if start + 2 >= commands.len || !portable_svg_group_clip_supported(&commands[start]) { return none }
	first := &commands[start + 1]
	limit := math.min(commands.len, start + portable_svg_group_max_paths + 2)
	for index in start + 1 .. limit {
		command := &commands[index]
		if command.kind == 'end_svg_mask_layer' {
			closing := command.mask_clip()
			if index > start + 1 && closing.is_svg_mask == mask.is_svg_mask
				&& closing.is_svg_content_mask == mask.is_svg_content_mask
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

fn (mut app BrowserApp) draw_portable_svg_mask_group(commands []layout.PaintCommand,
	start int, page_x f32, page_y f32, outer_viewport ?painting.Rect) int {
	if !app.portable_svg_group_allowed() { return start }
	mask := commands[start].mask_clip()
	end := portable_svg_mask_group_end(commands, start, mask) or { return start }
	if mask.is_svg_content_mask && mask.mask_operations.len == 0 { return end + 1 }
	scale := f64(app.ctx.scale)
	mut viewport := outer_viewport or { app.portable_device_viewport(page_y) }
	mut region := painting.Rect{}
	mut direct_crop := false
	if rect := svg_background_rectangular_clip(mask) {
		region = portable_device_transform([f64(1), 0, 0, 1, 0, 0]!, page_x, page_y, scale).map_rect(rect)
		direct_crop = [region.x, region.y, region.right(), region.bottom()]!.all(it == math.floor(it))
	} else {
		local := painting.Rect{mask.rect.x, mask.rect.y, mask.rect.width, mask.rect.height}
		if mask.is_svg_content_mask && local.is_empty() { return end + 1 }
		transform := portable_device_transform(mask.transform, page_x, page_y, scale)
		region = transform.map_rect(local)
		if mask.is_svg_content_mask && ![region.x, region.y, region.right(), region.bottom()]!.all(math.is_finite(it)) {
			return start
		}
	}
	viewport = viewport.intersection(region)
	key := app.portable_svg_group_key(commands, start, viewport, page_x, page_y)
	if app.draw_cached_portable_svg_group(key, 255) { return end + 1 }
	mut image := app.raster_portable_svg_group(commands[start + 1..end], viewport, page_x, page_y,
		1) or { return start }
	if image.bounds.is_empty() { return end + 1 }
	if mask.is_svg_content_mask {
		if !app.apply_portable_svg_content_mask(mut image, &mask, region, page_x, page_y, scale) { return start }
	} else if !direct_crop && !apply_portable_svg_clip(mut image, mask.path_components, page_x, page_y, scale) {
		return start
	}
	app.draw_portable_svg_group_image(image, 255, key)
	if mask.is_svg_content_mask && portable_svg_mask_diagnostics {
		eprintln('VOX_SVG_MASK luminance=${mask.mask_luminance} operations=${mask.mask_operations.len} paths=${image.paths} texture=${image.bounds.width}x${image.bounds.height}')
	} else if !mask.is_svg_content_mask && portable_svg_clip_diagnostics {
		eprintln('VOX_SVG_CLIP crop=${direct_crop} components=${mask.path_components.len} paths=${image.paths} texture=${image.bounds.width}x${image.bounds.height}')
	}
	return end + 1
}

fn apply_portable_svg_clip(mut image PortableSVGGroupImage, components []layout.PaintPath,
	page_x f32, page_y f32, scale f64) bool {
	bounds := image.bounds
	mut coverage := []u8{len: bounds.width * bounds.height}
	for part in components {
		if part.path_data.len < layout.compatibility_clip_path_segment_stride { continue }
		path := cpuraster.canvas_path(part.path_data, part.path_even_odd)
		transform := portable_device_transform(part.transform, page_x, page_y, scale)
		if !cpuraster.fill_opaque_coverage(mut coverage, bounds.width, bounds.height,
			path, portable_svg_surface_matrix(transform, bounds)) {
			return false
		}
	}
	// Components form one coverage mask over the resolved SVG source.
	for i, value in coverage {
		alpha := 4 * i + 3
		image.pixels[alpha] = portable_svg_mask_alpha(image.pixels[alpha], value)
	}
	return true
}
