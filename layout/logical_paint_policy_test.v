module layout

import html
import painting
import platform

fn test_archived_logical_paint_policy_preserves_document_density_and_line_offsets() {
	mut document := html.parse_document('<!doctype html><div>Line</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	result := document_layout_result(document) or { panic('layout') }
	font := &platform.Font{family:'Test', point_size:10, font_rendering_policy:.chromium}
	run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{code_point:u32(`a`), advance:6}])
	fragment := TextFragment{
		y:21.5
		paint_line_top:20.265625
		layout_handle:voidptr(result.root)
		paintable_fragment:painting.PaintableFragment{glyph_run:run}
	}
	assert document.display_device_pixel_ratio() == 2
	assert document.layout_coordinate_scale() == 1
	assert text_fragment_paint_top(fragment) == if retain_logical_paint_snapping { 21.234375 } else { 21.734375 }
	next := TextFragment{...fragment, y:22.265625}
	assert text_fragment_paint_top(next) - text_fragment_paint_top(fragment) == next.y - fragment.y
	document.set_font_rendering_policy(.libweb)
	assert chromium_paint_pixel_scale(voidptr(result.root)) == 1
}

fn test_archived_logical_paint_policy_keeps_fractional_background_geometry() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}.box{position:absolute;left:20.25px;top:20.25px;width:140.5px;height:40.5px;
		box-sizing:border-box;border:1px solid #123;border-radius:9px;background:rgb(1 2 3)}
	</style><div class="box"></div><svg width="1" height="1"></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut background_seen := false
	mut border_seen := false
	for command in commands {
		if command.kind == 'fill_rect' && command.color == 'rgb(1 2 3)' {
			background_seen = true
			assert command.x == if retain_logical_paint_snapping { 20.5 } else { 21.0 }
			assert command.y == command.x
			assert command.width == if retain_logical_paint_snapping { 140.0 } else { 139.5 }
			assert command.height == if retain_logical_paint_snapping { 40.0 } else { 39.5 }
		}
		if command.kind == 'paint_uniform_border' {
			border_seen = true
			assert command.x == if retain_logical_paint_snapping { 20.5 } else { 21.0 }
			assert command.stroke_width == 1
			assert command.corner_radii.top_left == CornerRadius{8.5,8.5}
		}
	}
	assert background_seen && border_seen
}
