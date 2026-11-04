module layout

import painting
import math

// A CSS transform establishes a paint-offset coordinate space even when its
// matrix is the identity (for example translateX(0)). Keep solid and rounded
// background geometry in that space rather than snapping absolute coordinates.
fn chromium_local_background(mut command PaintCommand, box &BlockBox, color_background bool) {
	if box.snaps_background_rect && color_background && command.kind == 'fill_rect'
		&& command.radius == 0 {
		transform := normalized_affine(command.transform)
		if transform[0] == 1 && transform[1] == 0 && transform[2] == 0 && transform[3] == 1
			&& (transform[4] != math.trunc(transform[4]) || transform[5] != math.trunc(transform[5])) {
			// Descendants inherit the ancestor's paint transform without owning
			// a transform themselves. Their fractional coverage still needs Skia.
			command.antialiased_rect = true
		}
	}
	if !box.snaps_background_rect || !box.uses_own_paint_transform_4x4
		|| command.local_border_data != unsafe { nil }
		|| !(command.kind == 'fill_rounded_rect'
			|| (command.kind == 'fill_rect' && (command.radius > 0 || color_background))) {
		return
	}
	plain := command.kind == 'fill_rect' && command.radius == 0
	x := if plain { box.x - box.padding.left - box.border.left } else { box.x }
	y := if plain { box.y - box.padding.top - box.border.top } else { box.y }
	own := normalized_affine(box.own_paint_transform)
	// Translation-only solid backgrounds keep the snapped absolute layout box.
	// Localizing them would restore the discarded fractional paint offset.
	if plain && own[0] == 1 && own[1] == 0 && own[2] == 0 && own[3] == 1 {
		// The retained translation can still leave fractional device edges.
		// Keep their coverage and color blend in the document's Skia raster.
		command.antialiased_rect = true
		return
	}
	command.local_border_data = &PaintLocalBorderData{
		origin_x:                x
		origin_y:                y
		transform_context_index: box.own_transform_visual_context_idx
		initial_transform:       painting.Affine{ a: own[0], b: own[1], c: own[2], d: own[3], e: own[4], f: own[5] }
	}
	command.x -= x
	command.y -= y
}
