module layout

import html

fn chromium_background_paint_rect_command(left string) PaintCommand {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#trophy { position:absolute; left:${left}; top:214px; width:96px; height:128.5px;
			background:url(trophy.png) 50% 50%/cover no-repeat }
	</style><div id="trophy"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	for command in commands {
		if command.kind == 'draw_background_image' { return command }
	}
	panic('missing background image')
}

fn test_snapped_backgrounds_retain_blinks_unsnapped_paint_rect() {
	// Discord's floating trophy: the clip snaps to whole pixels, while Blink's
	// background geometry still starts at the fractional box edge.
	command := chromium_background_paint_rect_command('915.734375px')
	data := command.image()
	assert [data.image_clip_x, data.image_clip_y, data.image_clip_width, data.image_clip_height] == [916.0, 214, 96, 129]
	assert data.background_paint_rect() == LayoutRect{915.734375, 214, 96, 128.5}
}

fn test_integral_backgrounds_record_no_paint_rect_offset() {
	command := chromium_background_paint_rect_command('916px')
	data := command.image()
	assert data.background_paint_rect() == LayoutRect{916, 214, 96, 128.5}
	assert chromium_background_paint_rect_snap(LayoutRect{0, 0, 10, 10}, LayoutRect{0, 0, 10, 10}) or { 1 } == 0
	assert chromium_background_paint_rect_snap(LayoutRect{0.75, 0, 10, 10}, LayoutRect{0, 0, 10, 10}) == none
}
