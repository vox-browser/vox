module main

import layout

fn test_retained_paint_color_keeps_components_and_applies_opacity_once() {
	command := layout.PaintCommand{
		color:           'rgb(246, 246, 254)'
		opacity:         .4
		srgb_color_data: &layout.PaintSRGBColor{'rgb(246, 246, 254)', [f64(.9634), .96506, .9966,
			.59]!}
	}
	assert chromium_retained_paint_color(command)? == [f32(.9634), .96506, .9966, f32(.59 * .4)]!
	// A later serialized-color replacement must not inherit stale metadata.
	changed := layout.PaintCommand{ ...command, color: '#ffffff' }
	assert chromium_retained_paint_color(changed) == none
	assert chromium_retained_paint_color(layout.PaintCommand{ color: '#ffffff' }) == none
}
