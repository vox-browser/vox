module layout

import painting

// NativeThemeBase::PaintCheckbox(): the default enabled light-theme checkbox.
// Build the check in CSS coordinates before projecting its f32 SkPath points.
fn append_chromium_checked_checkbox(mut commands []PaintCommand, rect painting.IntRect,
	scale f64, opacity f64) {
	x := f32(f64(rect.x) / scale)
	y := f32(f64(rect.y) / scale)
	w := f32(f64(rect.width) / scale)
	h := f32(f64(rect.height) / scale)
	projection := f32(scale)
	points := [
		painting.Point{f64((x + w * f32(0.2)) * projection), f64((y + h / 2) * projection)},
		painting.Point{f64((x + w * f32(0.2) + w * f32(0.2)) * projection), f64((y + h / 2 + h * f32(0.2)) * projection)},
		painting.Point{f64((x + w - w * f32(0.2)) * projection), f64((y + h * f32(0.2)) * projection)},
	]
	path := painting.ClipPathVisualData{
		segments: [
			painting.ClipPathSegment{ kind: .move_to, point: points[0] },
			painting.ClipPathSegment{ kind: .line_to, point: points[1] },
			painting.ClipPathSegment{ kind: .line_to, point: points[2] },
		]
	}
	commands << PaintCommand{
		kind:                'fill_rect'
		x:                   f64(rect.x) + 0.2 * scale
		y:                   f64(rect.y) + 0.2 * scale
		width:               f64(rect.width) - 0.4 * scale
		height:              f64(rect.height) - 0.4 * scale
		radius:              2 * scale
		color:               'rgb(255 255 255)'
		opacity:             opacity
		force_dark_role:     .background
		underlays_next:      true
		checkbox_theme_data: &PaintCheckboxThemeData{rect: rect, scale: scale}
		force_dark_role_set: true
	}
	commands << PaintCommand{
		kind:                'fill_rect'
		x:                   rect.x
		y:                   rect.y
		width:               rect.width
		height:              rect.height
		radius:              2 * scale
		color:               'rgb(0 117 255)'
		checkbox_theme_data: &PaintCheckboxThemeData{rect: rect, scale: scale, fill_inset: 0}
		opacity:             opacity
		force_dark_role:     .background
		force_dark_role_set: true
	}
	commands << PaintCommand{
		kind:                'draw_svg_path'
		x:                   rect.x
		y:                   rect.y
		width:               rect.width
		height:              rect.height
		svg_data:            &PaintSVGPathData{
			path:      painting_path_svg(path)
			path_data: compatibility_pack_clip_path_segments(path)
		}
		stroke_color:        'rgb(255 255 255)'
		stroke_width:        f64(h * f32(0.16) * projection)
		opacity:             opacity
		force_dark_role:     .foreground
		force_dark_role_set: true
	}
}
