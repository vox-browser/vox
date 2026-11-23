module main

import cpuraster
import layout
import painting

// The portable scissor handles rectangular bounds. Resolve rounded corners in
// the gradient texture's device space, where the shared rasterizer can retain
// runs of fully covered pixels without allocating a second texture-sized mask.
fn portable_background_raster_clip(command &layout.PaintCommand, bounds painting.IntRect,
	page_x f32, page_y f32, scale f64) ?cpuraster.RasterClip {
	mut paths := []cpuraster.Path{}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.corner_radii == layout.BoxRadii{} || clip.is_path || clip.is_svg_mask
				|| clip.is_svg_content_mask {
				continue
			}
			transform := portable_device_transform(clip.transform, page_x, page_y, scale)
			paths << portable_background_rounded_clip_path(clip.rect, clip.corner_radii, transform, bounds)
		}
	}
	if command.gradient_background_layer {
		image := command.image()
		if image.image_clip_radii != layout.BoxRadii{} {
			rect := layout.LayoutRect{image.image_clip_x, image.image_clip_y,
				image.image_clip_width, image.image_clip_height}
			transform := portable_device_transform(command.transform, page_x, page_y, scale)
			paths << portable_background_rounded_clip_path(rect, image.image_clip_radii, transform, bounds)
		}
	}
	if paths.len == 0 { return none }
	clip := cpuraster.canvas_raster_clip(bounds.width, bounds.height, paths)
	if clip.covers_surface(bounds.width, bounds.height) { return none }
	return clip
}

fn portable_background_rounded_clip_path(rect layout.LayoutRect, radii layout.BoxRadii,
	transform painting.Affine, bounds painting.IntRect) cpuraster.Path {
	edges := cpuraster.Rect{f32(rect.x), f32(rect.y), f32(rect.x + rect.width), f32(rect.y + rect.height)}
	corners := [f32(radii.top_left.x), f32(radii.top_left.y), f32(radii.top_right.x), f32(radii.top_right.y),
		f32(radii.bottom_right.x), f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y)]!
	matrix := cpuraster.Matrix{f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d),
		f32(transform.e - f64(bounds.x)), f32(transform.f - f64(bounds.y))}
	return cpuraster.rounded_rect(edges, corners).clip_path(matrix)
}
