module layout

import dom
import html

fn test_chromium_svg_strokes_keep_float_user_units_for_numbers_lengths_and_calculations() {
	for source in ['1.2', '1.2px', 'calc(1px + .2px)', '12%'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{width:10px;height:10px}path{stroke:black;fill:none;stroke-width:${source}}</style><svg viewBox="0 0 10 10"><path d="M1 1L9 9"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 100, 80)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		paths := commands.filter(it.kind == 'draw_svg_path')
		assert paths.len == 1
		assert paths[0].stroke_width == f64(f32(1.2)), source
	}
}

fn test_svg_stroke_resolution_keeps_absolute_unit_conversion_and_libweb_rounding() {
	for policy in [dom.FontRenderingPolicy.chromium, .libweb] {
		mut document := html.parse_document('<!doctype html><style>path{stroke:black;stroke-width:.1cm}</style><svg><path d="M1 1L9 9"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout_document_typed_in_viewport(document, 100, 80)
		paths := display_list_commands(document.record_display_list() or { panic('paint') })
			.filter(it.kind == 'draw_svg_path')
		assert paths.len == 1
		assert paths[0].stroke_width == if policy == .chromium {
			f64(f32(96.0 / 25.4))
		} else {
			3.78125
		}
	}
}
