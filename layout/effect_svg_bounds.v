module layout

import os

const retain_unbounded_svg_effects = os.getenv('VOX_RETAIN_UNBOUNDED_SVG_EFFECTS') != ''
const effect_svg_bounds_diagnostics = os.getenv('VOX_EFFECT_SVG_BOUNDS_DIAGNOSTICS') != ''

fn effect_svg_fill_ink_bounds(command &PaintCommand) ?LayoutRect {
	data := command.svg_data
	// The shared serialized-path envelope bounds solid fills. Stroke joins,
	// pattern resources and gradients retain their existing unbounded path.
	if command.color == '' || command.stroke_color != '' || command.outer_shadow
		|| command.blur != 0 || data == unsafe { nil } || data.fill_pattern != none
		|| data.stroke_pattern != none || data.svg_gradient_data != none {
		return none
	}
	ink := paint_svg_path_native_ink_bounds(command) or { return none }
	// Retain a screen-space fringe after the complete path/command transform.
	return LayoutRect{ink.x - 1, ink.y - 1, ink.width + 2, ink.height + 2}
}

fn report_effect_svg_bounds(ink LayoutRect) {
	eprintln('Vox effect SVG bounds: bounded solid-fill group ${ink.x},${ink.y} ${ink.width}x${ink.height}')
}
