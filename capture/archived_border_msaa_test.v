module main

import html
import layout

fn test_archived_border_msaa_retains_arc_tiles_without_changing_border_geometry() {
	for style in ['border-top:2px solid red', 'border-left:1px solid blue',
		'border-bottom:3px solid green'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:24px;top:440px;width:320px;height:200px;${style}}</style><div></div>')
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
		commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
		borders := commands.filter(it.kind == 'draw_svg_path' && it.force_dark_role == .border)
		assert borders.len == 1
		border := borders[0]
		original_path := border.svg().path_data.clone()
		assert chromium_border_has_diagonal_path_with_arc_policy(border, true)
		assert !chromium_border_has_diagonal_path_with_arc_policy(border, false)
		assert border.svg().path_data == original_path
		document.finalize()
	}
}

fn test_archived_border_msaa_distinguishes_arc_records_from_straight_and_diagonal_lines() {
	for item in [
		[f32(4), 0, 0, 5, 5, 0, 1], // omitted arc
		[f32(4), 10, 0, 0, 5, 0, 1], // horizontal zero-radius arc
		[f32(4), 0, 10, 5, 0, 0, 1], // vertical zero-radius arc
		[f32(4), 10, 10, 0, 5, 1, 1], // zero-radius diagonal
		[f32(4), 10, 10, 5, 5, 1, 1], // curved arc
		[f32(1), 10, 0, 0, 0, 0, 0], // ordinary horizontal line
		[f32(1), 0, 10, 0, 0, 0, 0], // ordinary vertical line
		[f32(1), 10, 10, 0, 0, 1, 1], // ordinary diagonal line
	] {
		data := [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			item[0], item[1], item[2], 0, 0, 0, 0, item[3], item[4], 0, 0, 0]
		command := layout.PaintCommand{
			kind: 'draw_svg_path'
			force_dark_role: .border
			opacity: 1
			svg_data: &layout.PaintSVGPathData{path_data: data}
		}
		assert chromium_border_has_diagonal_path_with_arc_policy(command, false) == (item[5] == 1)
		assert chromium_border_has_diagonal_path_with_arc_policy(command, true) == (item[6] == 1)
	}
	assert !chromium_border_has_diagonal_path_with_arc_policy(layout.PaintCommand{}, true)
}
