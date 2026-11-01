module layout

fn chromium_pair_contoured_background(mut commands []PaintCommand, start int,
	border_start int, border_end int, parameters [4]f64) {
	if parameters == [f64(1), 1, 1, 1]! || start < 0 || border_end > commands.len
		|| border_end != border_start + 1 || commands[border_start].kind != 'paint_uniform_border' {
		return
	}
	mut background := start
	for background < border_start && commands[background].kind == 'paint_outer_box_shadow' {
		background++
	}
	if background + 1 != border_start || commands[background].kind !in ['fill_rect', 'fill_rounded_rect']
		|| commands[background].opacity != commands[border_start].opacity
		|| commands[background].clip_outs != commands[border_start].clip_outs {
		return
	}
	commands[background].underlays_next = true
}

// Share the existing rare border payload instead of widening every command.
// Shape-only snapshots keep their original coordinate space; transformed boxes
// retain their previously resolved local paint origin too.
fn chromium_record_corner_shapes(mut command PaintCommand, box &BlockBox,
	border_rect LayoutRect, radii BoxRadii) {
	parameters := box.decorations().corner_shapes
	if !box.snaps_background_rect || parameters == [f64(1), 1, 1, 1]!
		|| command.kind !in ['fill_rect', 'fill_rounded_rect', 'paint_uniform_border',
			'paint_outer_box_shadow'] {
		return
	}
	mut rect := border_rect
	local := command.local_border_data
	if local != unsafe { nil } {
		if local.has_local_geometry {
			rect = LayoutRect{
				...rect
				x: rect.x - local.origin_x
				y: rect.y - local.origin_y
			}
		}
		command.local_border_data = &PaintLocalBorderData{
			...*local
			corner_shapes:      parameters
			shape_border_rect:  rect
			shape_border_radii: radii
		}
	} else {
		command.local_border_data = &PaintLocalBorderData{
			has_local_geometry: false
			corner_shapes:      parameters
			shape_border_rect:  rect
			shape_border_radii: radii
		}
	}
}
