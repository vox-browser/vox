module main

import html
import layout

fn test_drop_shadow_paint_keeps_explicit_color_and_alpha() {
	for color in ['white', '#fff9', 'rgb(255 255 255 / .6)', 'red'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{width:80px;height:40px;fill:black;filter:drop-shadow(4px 8px 4px ${color})}</style><svg viewBox="0 0 80 40"><path d="M0 0H40V20H0Z"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 200, 100)
		commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
		filters := commands.filter(it.kind == 'begin_css_filter_layer')
		assert filters.len == 1
		filter := filters[0].visual_layer().filter or { panic('missing filter') }
		assert filter.operations.len == 1
		operation := filter.operations[0]
		eprintln('${color}: ${operation.color.r},${operation.color.g},${operation.color.b},${operation.color.a}')
		assert operation.kind == 'drop-shadow'
		assert operation.color.r == 255
		assert operation.color.g == if color == 'red' { 0 } else { 255 }
		assert operation.color.b == if color == 'red' { 0 } else { 255 }
		assert operation.color.a == if color in ['white', 'red'] { 255 } else { 153 }
	}
}
