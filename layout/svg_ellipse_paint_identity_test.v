module layout

import dom
import html

fn ellipse_identity_commands(mut document dom.Document) []PaintCommand {
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return display_list_commands(document.record_display_list() or { panic('missing display list') }).filter(it.kind == 'draw_svg_path')
}

fn test_chromium_svg_ellipse_retains_computed_geometry_and_authored_arc_identity() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#oval{cx:25%;cy:50%;rx:auto;ry:10%}</style><svg width="200" height="100"><circle cx="4" cy="4" r="4"/><ellipse id="oval" cx="1" cy="2" rx="3" ry="4"/><path d="M8 4A4 4 0 0 1 4 8A4 4 0 0 1 0 4A4 4 0 0 1 4 0A4 4 0 0 1 8 4"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		commands := ellipse_identity_commands(mut document)
		assert commands.len == 3
		for index in 0 .. 2 {
			data := commands[index].svg().path_data
			if policy == .chromium {
				assert data.len == 12
				assert data[0] == 6
				assert data[1..5] == if index == 0 { [f32(0), 0, 8, 8] } else { [f32(40), 40, 60, 60] }
			} else {
				assert data.len == 60
				assert data[0] == 0 && data[12] == 4
			}
		}
		assert commands[2].svg().path_data.len == 60
		assert commands[2].svg().path_data[0] == 0
		assert commands[2].svg().path_data[12] == 4
		// The common record includes the independent shared sRGB payload pointer.
		// Ellipse encoding still adds no common record fields.
		assert sizeof(PaintCommand) <= 1328
	}
}

fn test_retained_ellipse_geometry_updates_without_mutating_earlier_commands() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="200" height="100"><ellipse id="oval" cx="30.25" cy="25.5" rx="10.125" ry="5.25" transform="translate(3 7)"/><circle r="0"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	before := ellipse_identity_commands(mut document)
	assert before.len == 1
	assert before[0].svg().path_data[1..5] == [f32(20.125), 20.25, 40.375, 30.75]
	assert before[0].svg().path_transform == [f64(1), 0, 0, 1, 3, 7]!
	mut oval := document.get_element_by_id('oval')?
	oval.set_attribute_value('rx', '20.125')
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	after := ellipse_identity_commands(mut document)
	assert after[0].svg().path_data[1..5] == [f32(10.125), 20.25, 50.375, 30.75]
	assert before[0].svg().path_data[1..5] == [f32(20.125), 20.25, 40.375, 30.75]
}
