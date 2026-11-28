// vtest build: macos
module main

import html
import layout

fn test_disjoint_rounded_batch_preserves_gaps_and_declines_overlap_or_state_boundaries() {
	mut document := html.parse_document($embed_file('@VMODROOT/Tests/Browser/Brave/input/disjoint-rounded-shadow-groups.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	source := root.paint_commands()
	mut starts := []int{}
	mut path := -1
	for i, command in source {
		if command.kind == 'paint_outer_box_shadow' { starts << i }
		if command.kind == 'draw_svg_path' { path = i }
	}
	assert starts.len == 2 && path >= 0
	mut commands := source[starts[0]..starts[0] + 3].clone()
	commands << source[path]
	commands << source[starts[1]..starts[1] + 3]
	// Exercise coincident opaque background/border geometry. Ordinary outer
	// border-box underlays retain their separate existing renderer path.
	for start in [0, 4] {
		border := &commands[start + 2]
		commands[start + 1] = layout.PaintCommand{
			...commands[start + 1]
			x:              border.x
			y:              border.y
			width:          border.width
			height:         border.height
			radius:         border.corner_radii.top_left.x
			underlays_next: false
		}
	}
	layers := []int{len: commands.len}
	assert rounded_outer_batch_indices(commands, layers, 0) == [0, 1, 2, 4, 5, 6]
	assert rounded_outer_batch_indices(commands[..3], layers[..3], 0).len == 0
	mut inactive_stroke := commands.clone()
	inactive_stroke[3] = layout.PaintCommand{ ...commands[3], stroke_color: 'none', stroke_width: 1, opacity: 0.5 }
	assert rounded_outer_batch_indices(inactive_stroke, layers, 0) == [0, 1, 2, 4, 5, 6]
	for replacement in [
		layout.PaintCommand{ ...commands[3], transform: [f64(1), 0, 0, 1, 100, 0]! },
		layout.PaintCommand{ ...commands[3], kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ ...commands[3], kind: 'draw_text_shadow' },
	] {
		mut altered := commands.clone()
		altered[3] = replacement
		assert rounded_outer_batch_indices(altered, layers, 0).len == 0
	}
	mut foreign := layers.clone()
	foreign[4] = 1
	assert rounded_outer_batch_indices(commands, foreign, 0).len == 0
	mut translucent := commands.clone()
	translucent[4] = layout.PaintCommand{ ...commands[4], group_opacity: 0.5 }
	assert rounded_outer_batch_indices(translucent, layers, 0).len == 0
	assert rounded_outer_batch_indices(commands, []int{}, 0).len == 0
	mut underlay := commands.clone()
	underlay[1] = layout.PaintCommand{ ...commands[1], underlays_next: true }
	assert rounded_outer_group_end(underlay, layers, 0) == 0
	assert rounded_outer_batch_indices(underlay, layers, 0) == [0, 1, 2, 4, 5, 6]
	mut contoured := commands.clone()
	contoured[0] = layout.PaintCommand{
		...commands[0]
		local_border_data: &layout.PaintLocalBorderData{
			corner_shapes: [f64(2), 2, 2, 2]!
		}
	}
	assert rounded_outer_batch_indices(contoured, layers, 0).len == 0
}

fn test_rounded_outer_mask_bounds_keep_integer_phase_and_decline_truncated_ink() {
	mut mask := []u8{len: 8 * 6}
	mask[2 * 8 + 3] = 1
	mask[3 * 8 + 5] = 255
	ink := rounded_outer_mask_ink(mask, 8, 6, -7, 11) or { panic('Expected bounded coverage') }
	assert ink == layout.LayoutRect{-4, 13, 3, 2}
	mask[3 * 8] = 1
	assert rounded_outer_mask_ink(mask, 8, 6, -7, 11) == none
	assert rounded_outer_mask_ink([]u8{}, 8, 6, 0, 0) == none
	assert rounded_outer_mask_ink([]u8{len: 48}, 8, 6, 0, 0) == none
}
