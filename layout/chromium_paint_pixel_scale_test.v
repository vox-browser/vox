module layout

import html
import painting
import platform

fn test_chromium_paint_density_is_relative_to_layout_coordinates() {
	mut document := html.parse_document('<!doctype html><div>Density</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	result := document_layout_result(document) or { panic('layout') }
	for density in [f64(1), 1.5, 2, 3] {
		document.set_display_device_pixel_ratio(density)
		for coordinates in [f64(1), 2] {
			document.set_layout_coordinate_scale(coordinates)
			assert chromium_paint_pixel_scale(voidptr(result.root)) == density / coordinates
		}
	}
	document.set_font_rendering_policy(.libweb)
	assert chromium_paint_pixel_scale(voidptr(result.root)) == 1
	assert chromium_paint_pixel_scale(unsafe { nil }) == 1
}

fn test_fractional_backgrounds_and_borders_follow_the_presenting_device_grid() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}.box{position:absolute;left:20.25px;top:20.25px;width:140.5px;height:40.5px;
		box-sizing:border-box;border:1px solid #123;border-radius:9px;background:rgb(1 2 3)}
	</style><div class="box"></div><svg width="1" height="1"></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for density in [f64(1), 2, 1] {
		document.set_display_device_pixel_ratio(density)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut background_seen := false
		mut border_seen := false
		for command in commands {
			if command.kind == 'fill_rect' && command.color == 'rgb(1 2 3)' {
				background_seen = true
				assert command.x == if density == 2 { 21.0 } else { 20.5 }, 'density=${density}, x=${command.x}'
				assert command.y == command.x
				assert command.width == if density == 2 { 139.5 } else { 140.0 }
				assert command.height == if density == 2 { 39.5 } else { 40.0 }
			}
			if command.kind == 'paint_uniform_border' {
				border_seen = true
				assert command.x == if density == 2 { 21.0 } else { 20.5 }
				assert command.y == command.x
				assert command.width == if density == 2 { 139.5 } else { 140.0 }
				assert command.stroke_width == 1
				assert command.corner_radii.top_left == CornerRadius{8.5, 8.5}
			}
		}
		assert background_seen && border_seen
	}
}

fn test_device_line_origin_snapping_keeps_inline_alignment_and_libweb_policy() {
	mut document := html.parse_document('<!doctype html><div>Line</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	result := document_layout_result(document) or { panic('layout') }
	font := &platform.Font{ family: 'Test', point_size: 10, font_rendering_policy: .chromium }
	run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{ code_point: u32(`a`), advance: 6 }])
	fragment := TextFragment{
		y:                  21.5
		paint_line_top:     20.265625
		layout_handle:      voidptr(result.root)
		paintable_fragment: painting.PaintableFragment{ glyph_run: run }
	}
	assert text_fragment_paint_top(fragment) == 21.734375
	next := TextFragment{ ...fragment, y: 22.265625 }
	assert text_fragment_paint_top(next) - text_fragment_paint_top(fragment) == next.y - fragment.y
	document.set_display_device_pixel_ratio(1)
	assert text_fragment_paint_top(fragment) == 21.234375
	document.set_font_rendering_policy(.libweb)
	libweb_font := &platform.Font{ family: 'Test', point_size: 10, font_rendering_policy: .libweb }
	libweb_run := platform.GlyphRun.new(libweb_font, .ltr, [platform.Glyph{ code_point: u32(`a`), advance: 6 }])
	libweb_fragment := TextFragment{
		...fragment
		paintable_fragment: painting.PaintableFragment{ glyph_run: libweb_run }
	}
	assert text_fragment_paint_top(libweb_fragment) == fragment.y
}
