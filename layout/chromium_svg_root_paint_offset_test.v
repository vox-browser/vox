module layout

import html
import dom

fn test_chromium_svg_root_snaps_its_paint_origin_without_changing_layout() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{position:absolute;left:3.5px;top:6.5px;width:24px;height:24px}</style><svg id="icon" viewBox="0 0 24 24"><path d="M0 0H24V24H0Z"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		root := layout_document_typed_in_viewport(document, 100, 80)
		commands := root.paint_commands().filter(it.kind == 'draw_svg_path')
		assert commands.len == 1
		expected_x := if policy == .chromium { f64(4) } else { f64(3.5) }
		expected_y := if policy == .chromium { f64(7) } else { f64(6.5) }
		assert commands[0].svg().path_transform == [f64(1), 0, 0, 1, expected_x, expected_y]!
		icon := document.get_element_by_id('icon') or { panic('missing SVG') }
		assert icon.get_bounding_client_rect().x == 3.5
		assert icon.get_bounding_client_rect().y == 6.5
	}
}

fn test_chromium_svg_root_retains_fractional_nested_viewports_and_local_transforms() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#icon{position:absolute;left:3.5px;top:6.5px;width:24px;height:24px}</style><svg id="icon" viewBox="0 0 24 24"><svg x="0.25" y="0.75" width="20" height="20"><path transform="translate(.125 .25)" d="M0 0H8V8H0Z"/></svg></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 100, 80)
	commands := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	assert commands[0].svg().path_transform == [f64(1), 0, 0, 1, 4.375, 8]!
}

fn test_chromium_svg_root_snaps_before_its_fractional_padding() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{position:absolute;left:3.5px;top:6.5px;width:24px;height:24px;padding:.25px}</style><svg viewBox="0 0 24 24"><path d="M0 0H8V8H0Z"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 100, 80)
	commands := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	assert commands[0].svg().path_transform == [f64(1), 0, 0, 1, 4.25, 7.25]!
}
