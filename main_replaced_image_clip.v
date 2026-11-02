module main

import layout
import math
import painting

// A replaced image with a rectangular content clip can carry one retained
// overflow clip in its GPU draw. Other clips stay on the native
// context, including paths, masks, and clips in an ancestor's coordinate space.
fn replaced_image_gpu_ancestor_clip_index(command &layout.PaintCommand) int {
	if !command.has_clip
		|| command.clip_list == unsafe { nil } { return -1 }
	match command.kind {
		'draw_replaced_image' {
			paintable := command.image_paintable or { return -1 }
			if paintable.border_radii.has_any_radius() { return -1 }
		}
		'draw_video' {
			paintable := command.video_paintable or { return -1 }
			if paintable.border_radii.has_any_radius() { return -1 }
		}
		else { return -1 }
	}
	transform := normalized_paint_transform(command.transform)
	mut rectangle_index := -1
	for index := command.clip_list.items.len - 1; index >= 0; index-- {
		clip := command.clip_list.items[index]
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
			|| normalized_paint_transform(clip.transform) != transform { continue }
		r := clip.corner_radii
		if r.top_left.x > 0 || r.top_left.y > 0 || r.top_right.x > 0
			|| r.top_right.y > 0 || r.bottom_right.x > 0 || r.bottom_right.y > 0
			|| r.bottom_left.x > 0 || r.bottom_left.y > 0 { return index }
		// The GPU's clipped image draw and a later Quartz crop can choose
		// different bilinear samples. Preserve an actual rectangular crop in
		// the image operation too, without adding redundant containing clips.
		// Fractional edges and videos retain their existing replay path.
		if rectangle_index < 0 && command.kind == 'draw_replaced_image' {
			paintable := command.image_paintable or { continue }
			if paintable.is_svg_image { continue }
			rect := clip.rect
			if rect.width <= 0 || rect.height <= 0
				|| math.is_inf(rect.x, 0) || math.is_inf(rect.y, 0)
				|| math.is_inf(rect.width, 0) || math.is_inf(rect.height, 0)
				|| rect.x != math.floor(rect.x) || rect.y != math.floor(rect.y)
				|| rect.width != math.floor(rect.width) || rect.height != math.floor(rect.height) {
				continue
			}
			converter := painting.new_device_pixel_converter(1) or { continue }
			target := converter.rounded_device_rect(paintable.image_rect)
			if target.width <= 0 || target.height <= 0
				|| rect.x < target.x || rect.y < target.y
				|| rect.x + rect.width > target.right()
				|| rect.y + rect.height > target.bottom() { continue }
			if rect.x > target.x || rect.y > target.y || rect.x + rect.width < target.right()
				|| rect.y + rect.height < target.bottom() {
				rectangle_index = index
			}
		}
	}
	return rectangle_index
}

// Images, video frames and posters share the same GPU clip representation.
// The caller retains the replaced element's rectangular clip when transferring
// one ancestor, so object-fit cropping remains independent of overflow rounding.
fn replaced_image_gpu_clip_data(command &layout.PaintCommand, rect painting.IntRect,
	radii painting.CornerRadii, ancestor_index int) [12]f32 {
	if ancestor_index >= 0 && command.clip_list != unsafe { nil }
		&& ancestor_index < command.clip_list.items.len {
		clip := command.clip_list.items[ancestor_index]
		r := clip.corner_radii
		return [f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height),
			f32(r.top_left.x), f32(r.top_left.y), f32(r.top_right.x), f32(r.top_right.y),
			f32(r.bottom_right.x), f32(r.bottom_right.y), f32(r.bottom_left.x), f32(r.bottom_left.y)]!
	}
	return [f32(rect.x), f32(rect.y), f32(rect.width), f32(rect.height),
		f32(radii.top_left.horizontal), f32(radii.top_left.vertical),
		f32(radii.top_right.horizontal), f32(radii.top_right.vertical),
		f32(radii.bottom_right.horizontal), f32(radii.bottom_right.vertical),
		f32(radii.bottom_left.horizontal), f32(radii.bottom_left.vertical)]!
}
