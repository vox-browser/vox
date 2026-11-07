module main

import html
import layout
import math
import os

fn partial_border_gap_source() string {
	return '<!doctype html><style>body{margin:0}div{position:absolute;left:724px;top:722px;width:252px;height:49px;border-bottom:1px solid #e5e5e5}</style><div></div>'
}

fn test_square_border_gap_has_ink_without_requiring_multisampling() {
	mut document := html.parse_document(partial_border_gap_source())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	path := paths[0]
	assert path.force_dark_role == .border
	assert chromium_svg_compositor_path_supported(&path)
	assert chromium_msaa_trigger_rect(&path) == none
	ink := chromium_partial_gap_ink(&path) or { panic('square border ink is bounded') }
	assert ink.x >= 724 && ink.x + ink.width <= 976
	assert ink.y >= 771 && ink.y + ink.height <= 772
	for replacement in [
		layout.PaintCommand{...path, svg_data: unsafe { nil }},
		layout.PaintCommand{...path, blur: 1},
		layout.PaintCommand{...path, transform: [f64(1), 0, 0, 1, math.nan(), 0]!},
	] {
		assert chromium_partial_gap_ink(&replacement) == none
	}
}

fn test_disjoint_square_border_does_not_split_the_rounded_header() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/input/chromium-partial-rounded-border.html')!)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	source := root.paint_commands()
	mut start := -1
	for i, command in source {
		if command.kind == 'paint_partial_rounded_border' { start = i - 1; break }
	}
	assert start >= 0
	mut gap_document := html.parse_document(partial_border_gap_source())
	defer { gap_document.finalize() }
	gap_document.set_font_rendering_policy(.chromium)
	gap_root := layout.layout_document_typed_in_viewport(gap_document, 1024, 768)
	path := gap_root.paint_commands().filter(it.kind == 'draw_svg_path')[0]
	commands := [source[start], source[start + 1], path, source[start + 2]]
	layers := []int{len: commands.len}
	assert chromium_disjoint_partial_header_index(commands, layers, 0) == 3
	mut overlapping := commands.clone()
	overlapping[2] = layout.PaintCommand{...path, transform: [f64(1), 0, 0, 1, 0, -680]!}
	assert chromium_disjoint_partial_header_index(overlapping, layers, 0) == -1
}
