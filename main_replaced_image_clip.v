module main

import layout

// A replaced image with a rectangular content clip can carry one retained
// rounded overflow clip in its GPU draw. Other clips stay on the native
// context, including paths, masks, and clips in an ancestor's coordinate space.
fn replaced_image_gpu_ancestor_clip_index(command &layout.PaintCommand) int {
	if command.kind != 'draw_replaced_image' || !command.has_clip
		|| command.clip_list == unsafe { nil } { return -1 }
	paintable := command.image_paintable or { return -1 }
	if paintable.border_radii.has_any_radius() { return -1 }
	transform := normalized_paint_transform(command.transform)
	for index := command.clip_list.items.len - 1; index >= 0; index-- {
		clip := command.clip_list.items[index]
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
			|| normalized_paint_transform(clip.transform) != transform { continue }
		r := clip.corner_radii
		if r.top_left.x > 0 || r.top_left.y > 0 || r.top_right.x > 0
			|| r.top_right.y > 0 || r.bottom_right.x > 0 || r.bottom_right.y > 0
			|| r.bottom_left.x > 0 || r.bottom_left.y > 0 { return index }
	}
	return -1
}
