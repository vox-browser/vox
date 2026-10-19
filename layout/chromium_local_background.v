module layout

import painting

// A CSS transform establishes a paint-offset coordinate space even when its
// matrix is the identity (for example translateX(0)). Keep rounded geometry in
// that space instead of adding the layout offset to its control points.
fn chromium_local_background(mut command PaintCommand, box &BlockBox) {
	if !box.snaps_background_rect || !box.uses_own_paint_transform_4x4
		|| command.local_border_data != unsafe { nil }
		|| !(command.kind == 'fill_rounded_rect'
			|| (command.kind == 'fill_rect' && command.radius > 0)) {
		return
	}
	own := normalized_affine(box.own_paint_transform)
	command.local_border_data = &PaintLocalBorderData{
		origin_x:                box.x
		origin_y:                box.y
		transform_context_index: box.own_transform_visual_context_idx
		initial_transform:       painting.Affine{ a: own[0], b: own[1], c: own[2], d: own[3], e: own[4], f: own[5] }
	}
	command.x -= box.x
	command.y -= box.y
}
