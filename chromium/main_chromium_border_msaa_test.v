module main

import html
import layout
import os

fn test_dashed_border_paths_share_msaa_with_their_document_tile() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:812px;top:343px;width:197px;height:30px;border-top:1px dashed #ccc}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	triggers := chromium_msaa_triggers(commands)
	assert triggers.len == 1
	assert commands[triggers[0].command_index].svg().stroke_dasharray.len == 2
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 1, 256) == [1]
}

fn test_elliptical_border_shares_msaa_with_other_boxes_in_its_tiles() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/diagnostic/inset-rounded-box-shadow.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	triggers := chromium_msaa_triggers(commands)
	assert triggers.len == 1
	assert commands[triggers[0].command_index].kind == 'paint_uniform_border'
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 1, 256) == [0, 1]
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 2, 256) == [1, 2]
}

fn test_circular_and_square_uniform_borders_keep_analytic_tile_coverage() {
	for radius in [0.0, 12.5] {
		r := layout.CornerRadius{radius, radius}
		command := layout.PaintCommand{
			kind: 'paint_uniform_border'
			x: 48.5
			y: 43.5
			width: 299
			height: 129
			stroke_width: 1
			corner_radii: layout.BoxRadii{r, r, r, r}
		}
		assert chromium_msaa_triggers([command]).len == 0
	}
}

fn test_partial_rounded_border_clips_share_the_parent_tile_msaa_mode() {
	command := layout.PaintCommand{
		kind: 'paint_partial_rounded_border'
		x: 701
		y: 92
		width: 298
		height: 560
		points: [0.0, 1.0, 1.0, 1.0]
		corner_radii: layout.BoxRadii{layout.CornerRadius{}, layout.CornerRadius{10,10}, layout.CornerRadius{}, layout.CornerRadius{10,10}}
	}
	triggers := chromium_msaa_triggers([command])
	assert triggers.len == 1
	assert chromium_msaa_tiles_for_triggers(triggers, 0, 1, 256) == [0, 1, 2]
}

fn test_square_one_sided_borders_ignore_their_degenerate_corner_arcs() {
	for style in [
		'left:24px;top:733px;width:976px;height:62px;border-top:2px solid #2d2c2e',
		'left:511px;top:88px;width:1px;height:605px;border-left:1px solid #e0dfe0',
		'left:767px;top:426px;width:1px;height:267px;border-left:1px solid #e0dfe0',
	] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;box-sizing:border-box;${style}}</style><div></div>')
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
		commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
		borders := commands.filter(it.kind == 'draw_svg_path' && it.force_dark_role == .border)
		assert borders.len == 1
		assert borders[0].svg().path_data.len > 0
		assert !chromium_border_has_diagonal_path(borders[0])
		assert chromium_msaa_triggers(commands).len == 0
		document.finalize()
	}
}

fn test_degenerate_border_arcs_keep_straight_and_diagonal_line_semantics() {
	for item in [
		[f32(0), 0, 5, 5, 0], // Equal endpoints omit even a nonzero-radius arc.
		[f32(0), 10, 0, 5, 0],
		[f32(10), 0, 5, 0, 0],
		[f32(10), 10, 0, 5, 1], // A zero-radius diagonal is still a diagonal line.
		[f32(10), 10, 5, 5, 1], // A real curve still needs MSAA.
	] {
		data := [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			4, item[0], item[1], 0, 0, 0, 0, item[2], item[3], 0, 0, 0]
		command := layout.PaintCommand{
			kind: 'draw_svg_path'
			force_dark_role: .border
			opacity: 1
			svg_data: &layout.PaintSVGPathData{path_data: data}
		}
		assert chromium_border_has_diagonal_path(command) == (item[4] == 1)
		assert chromium_msaa_triggers([command]).len == int(item[4])
	}
}

fn test_axis_aligned_dashed_border_paths_keep_their_multisampled_pass() {
	command := layout.PaintCommand{
		kind: 'draw_svg_path'
		force_dark_role: .border
		opacity: 1
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				1, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			stroke_dasharray: [f64(2), 2]
		}
	}
	assert !chromium_border_has_diagonal_path(command)
	assert chromium_msaa_triggers([command]).len == 1
}
