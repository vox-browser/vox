module main

import cpuraster
import layout
import math
import os
import painting

const disable_portable_svg_clip = os.getenv('VOX_DISABLE_PORTABLE_SVG_CLIP') == '1'
const portable_svg_clip_diagnostics = os.getenv('VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS') == '1'

struct PortableSVGMaskGroup {
	end      int
	viewport SVGMaskViewport
}

struct SVGMaskViewport {
	rect    painting.Rect
	mixed   bool
	rounded bool
}

fn portable_svg_mask_group(commands []layout.PaintCommand, start int, mask &layout.PaintClip) ?PortableSVGMaskGroup {
	if mask.is_svg_content_mask {
		if disable_portable_svg_mask || !portable_svg_content_mask_supported(mask, true) { return none }
	} else if disable_portable_svg_clip || !mask.is_svg_mask || mask.path_components.len > 64 {
		return none
	}
	opening := &commands[start]
	if start + 2 >= commands.len || !portable_svg_group_clip_supported(opening, mask) { return none }
	first := &commands[start + 1]
	local := painting.Rect{mask.rect.x, mask.rect.y, mask.rect.width, mask.rect.height}
	mut base := SVGMaskViewport{rect: local}
	mut viewport := base
	if mask.is_svg_content_mask {
		base = svg_mask_viewport(base, opening, mask.transform)
		viewport = svg_mask_viewport(base, first, mask.transform)
	}
	limit := math.min(commands.len, start + portable_svg_group_max_paths + 2)
	for index in start + 1 .. limit {
		command := &commands[index]
		if command.kind == 'end_svg_mask_layer' {
			closing := command.mask_clip()
			if index > start + 1 && closing.is_svg_mask == mask.is_svg_mask
				&& closing.is_svg_content_mask == mask.is_svg_content_mask
				&& closing.cache_key == mask.cache_key && closing.scope_id == mask.scope_id
				&& closing.rect == mask.rect && closing.transform == mask.transform {
				return PortableSVGMaskGroup{index, viewport}
			}
			return none
		}
		if !portable_svg_group_path_supported(command, first, 1, mask) { return none }
		if mask.is_svg_content_mask && voidptr(command.clip_list) != voidptr(first.clip_list) {
			if svg_mask_viewport(base, command, mask.transform) != viewport
				|| ((viewport.mixed || viewport.rounded)
				&& !same_svg_mask_viewports(first.clip_list, command.clip_list)) {
				return none
			}
		}
	}
	return none
}

fn svg_mask_viewport(viewport SVGMaskViewport, command &layout.PaintCommand,
	mask_transform [6]f64) SVGMaskViewport {
	mut intersection := viewport.rect
	mut mixed := viewport.mixed
	mut rounded := viewport.rounded
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.corner_radii != layout.BoxRadii{} {
				rounded = true
			} else if clip.transform[1] != 0 || clip.transform[2] != 0 {
				if clip.transform == mask_transform {
					// These rectangles share local coordinates.
					rect := clip.rect
					intersection = intersection.intersection(painting.Rect{rect.x, rect.y, rect.width, rect.height})
				} else {
					mixed = true
				}
			}
		}
	}
	return SVGMaskViewport{intersection, mixed, rounded}
}

@[inline]
fn same_svg_mask_viewport(first &layout.PaintClip, other &layout.PaintClip) bool {
	return first.rect == other.rect && first.transform == other.transform
		&& first.corner_radii == other.corner_radii
}

fn same_svg_mask_viewports(first &layout.PaintClipList, other &layout.PaintClipList) bool {
	if first == unsafe { nil } || other == unsafe { nil } || first.items.len != other.items.len {
		return false
	}
	for i in 0 .. first.items.len {
		if !same_svg_mask_viewport(&first.items[i], &other.items[i]) { return false }
	}
	return true
}

fn (mut app BrowserApp) draw_portable_svg_mask_group(commands []layout.PaintCommand,
	start int, page_x f32, page_y f32, outer_viewport ?painting.Rect) int {
	if !app.portable_svg_group_allowed() { return start }
	mask := commands[start].mask_clip()
	group := portable_svg_mask_group(commands, start, &mask) or { return start }
	end := group.end
	if mask.is_svg_content_mask && mask.mask_operations.len == 0 { return end + 1 }
	scale := f64(app.ctx.scale)
	mut viewport := outer_viewport or { app.portable_device_viewport(page_y) }
	local := group.viewport.rect
	mut transform := painting.Affine{}
	mut region := painting.Rect{}
	mut direct_crop := false
	if rect := svg_background_rectangular_clip(mask) {
		region = portable_device_transform([f64(1), 0, 0, 1, 0, 0]!, page_x, page_y, scale).map_rect(rect)
		direct_crop = [region.x, region.y, region.right(), region.bottom()]!.all(it == math.floor(it))
	} else {
		if mask.is_svg_content_mask && local.is_empty() { return end + 1 }
		transform = portable_device_transform(mask.transform, page_x, page_y, scale)
		region = transform.map_rect(local)
		if mask.is_svg_content_mask && ![region.x, region.y, region.right(), region.bottom()]!.all(math.is_finite(it)) {
			return start
		}
	}
	viewport = viewport.intersection(region)
	key := app.portable_svg_group_key(commands, start, viewport, page_x, page_y)
	if app.draw_cached_portable_svg_group(key, 255) { return end + 1 }
	mut polygon := []painting.Point{}
	if group.viewport.mixed {
		polygon = svg_mask_viewport_polygon(local, transform, &commands[start],
			&commands[start + 1], mask.transform, page_x, page_y, scale) or { return start }
		if polygon.len < 3 { return end + 1 }
		viewport = viewport.intersection(svg_mask_polygon_bounds(polygon))
	}
	mut image := app.raster_portable_svg_group(commands[start + 1..end], viewport, page_x, page_y,
		1) or { return start }
	if image.bounds.is_empty() { return end + 1 }
	mut cacheable := true
	if mask.is_svg_content_mask {
		cacheable = app.apply_portable_svg_content_mask(mut image, &mask, page_x, page_y,
			scale) or { return start }
		if group.viewport.mixed {
			if !apply_portable_svg_mask_polygon(mut image, polygon) { return start }
		} else if (transform.b == 0 && transform.c == 0) || (transform.a == 0 && transform.d == 0) {
			apply_portable_svg_mask_region(mut image, region)
		} else {
			corners := svg_mask_rect_corners(local, transform)
			if !apply_portable_svg_mask_polygon(mut image, corners[..]) { return start }
		}
		if group.viewport.rounded && !apply_svg_mask_rounded_viewports(mut image, &commands[start],
			&commands[start + 1], page_x, page_y, scale) {
			return start
		}
	} else if !direct_crop && !apply_portable_svg_clip(mut image, mask.path_components, page_x, page_y, scale) {
		return start
	}
	app.draw_portable_svg_group_image(image, 255, if cacheable { key } else { PortableSVGGroupKey{} })
	if mask.is_svg_content_mask && portable_svg_mask_diagnostics {
		eprintln('VOX_SVG_MASK luminance=${mask.mask_luminance} operations=${mask.mask_operations.len} paths=${image.paths} texture=${image.bounds.width}x${image.bounds.height}')
	} else if !mask.is_svg_content_mask && portable_svg_clip_diagnostics {
		eprintln('VOX_SVG_CLIP crop=${direct_crop} components=${mask.path_components.len} paths=${image.paths} texture=${image.bounds.width}x${image.bounds.height}')
	}
	return end + 1
}

fn apply_portable_svg_mask_polygon(mut image PortableSVGGroupImage, polygon []painting.Point) bool {
	bounds := image.bounds
	// Rasterize the transformed region in texture coordinates. Its bounding
	// box is only for allocation and would expose pixels outside the mask.
	mut path := cpuraster.PathBuilder{}
	for i, point in polygon {
		x := f32(point.x - f64(bounds.x))
		y := f32(point.y - f64(bounds.y))
		if !math.is_finite(x) || !math.is_finite(y) { return false }
		if i == 0 { path.move_to(x, y) } else { path.line_to(x, y) }
	}
	path.close()
	mut coverage := []u8{len: bounds.width * bounds.height}
	if !cpuraster.fill_opaque_coverage(mut coverage, bounds.width, bounds.height, path.detach(),
		[f32(1), 0, 0, 1, 0, 0]!) {
		return false
	}
	apply_portable_svg_clip_coverage(mut image, coverage)
	return true
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
	apply_portable_svg_clip_coverage(mut image, coverage)
	return true
}

fn apply_portable_svg_clip_coverage(mut image PortableSVGGroupImage, coverage []u8) {
	for i, value in coverage {
		alpha := 4 * i + 3
		image.pixels[alpha] = portable_svg_mask_alpha(image.pixels[alpha], value)
	}
}
