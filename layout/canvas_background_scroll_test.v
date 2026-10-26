module layout

import html

fn test_canvas_background_images_follow_live_viewport_scroll() {
	for source in ['html', 'body'] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0} body{width:1000px;height:1200px}
			${source}{background-color:rgb(12 34 56);
			background-image:url("fade.png"),url("local.png"),linear-gradient(red,blue);
			background-attachment:scroll,local,fixed;background-repeat:no-repeat}
		</style><body></body>')
		mut window := html.WindowModel.create_top_level(document, none, 'canvas-background')!
		_ = layout_document_typed_in_viewport(document, 200, 150)
		result := document_layout_result(document) or { panic('missing layout') }
		_ = document.record_display_list() or { panic('missing initial list') }
		retained_count := result.paint_phase_command_count
		for offset in [[40.0, 70.0], [80.0, 200.0], [0.0, 0.0]] {
			_ = window.scroll(html.ScrollToOptions{ left: offset[0], top: offset[1], behavior: .instant })
			assert window.scroll_x() == offset[0] && window.scroll_y() == offset[1]
			commands := display_list_commands(document.record_display_list() or { panic('missing scrolled list') })
			images := commands.filter(it.kind == 'draw_background_image' && it.image().image_attachment == 'scroll')
			assert images.len == 1
			assert images[0].transform[4] == -offset[0]
			assert images[0].transform[5] == -offset[1]
			local := commands.filter(it.kind == 'draw_background_image' && it.image().image_attachment == 'local')
			assert local.len == 1
			assert local[0].transform[4] == 0 && local[0].transform[5] == 0
			assert local[0].image_scroll_offset_x == offset[0]
			assert local[0].image_scroll_offset_y == offset[1]
			fixed := commands.filter(it.kind == 'fill_gradient' && it.gradient_background_layer)
			assert fixed.len == 1
			assert fixed[0].transform[4] == 0 && fixed[0].transform[5] == 0
			colors := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(12 34 56)')
			assert colors.len == 1
			assert colors[0].transform[4] == 0 && colors[0].transform[5] == 0
			assert result.paint_phase_command_count == retained_count
		}
	}
}
