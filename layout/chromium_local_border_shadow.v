module layout

import math
import painting

// Transformed CSS decorations use the box's local paint-offset space. Snap
// their geometry in that space before applying the retained transform; snapping
// global coordinates changes rotated contours and the shadow's blur phase.
fn chromium_local_border_shadow(mut command PaintCommand, box &BlockBox, rect LayoutRect) {
	if !box.snaps_background_rect || !box.uses_own_paint_transform_4x4
		|| command.local_border_data != unsafe { nil }
		|| command.kind !in ['paint_uniform_border', 'paint_outer_box_shadow']
		|| rect.width <= 0 || rect.height <= 0
		|| rect.width != math.floor(rect.width) || rect.height != math.floor(rect.height) {
		return
	}
	own := normalized_affine(box.own_paint_transform)
	if own[0] == 1 && own[1] == 0 && own[2] == 0 && own[3] == 1 { return }
	matrix := box.own_paint_transform_4x4
	if matrix.m13 != 0 || matrix.m23 != 0 || matrix.m31 != 0 || matrix.m32 != 0
		|| matrix.m33 != 1 || matrix.m34 != 0 || matrix.m41 != 0 || matrix.m42 != 0
		|| matrix.m43 != 0 || matrix.m44 != 1 { return }
	command.local_border_data = &PaintLocalBorderData{
		origin_x: rect.x
		origin_y: rect.y
		transform_context_index: box.own_transform_visual_context_idx
		initial_transform: painting.Affine{ a: own[0], b: own[1], c: own[2], d: own[3], e: own[4], f: own[5] }
	}
	x := math.round(rect.x)
	y := math.round(rect.y)
	command.x -= x
	command.y -= y
	if command.box_shadow_data != unsafe { nil } {
		data := command.box_shadow_data
		command.box_shadow_data = &PaintBoxShadowData{
			...data
			content_rect: LayoutRect{data.content_rect.x - x, data.content_rect.y - y,
				data.content_rect.width, data.content_rect.height}
		}
	}
}
