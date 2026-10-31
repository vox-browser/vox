module layout

import html

fn test_chromium_gradient_repeats_respect_the_obscured_background_destination() {
	for color in ['#444', 'rgba(68,68,68,.5)'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}div{position:absolute;left:31px;top:31px;width:99px;height:38px;
			border:1px solid ${color};border-radius:10px;background:linear-gradient(135deg,#121b288f,#10151e8f)}
		</style><div></div>')
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 800, 600)
		commands := root.paint_commands().filter(it.kind == 'fill_gradient')
		assert commands.len == 1
		command := commands[0]
		image := command.image()
		destination := image.background_image_destination or { panic('missing gradient destination') }
		if color == '#444' {
			assert destination == LayoutRect{32, 32, 99, 38}
			assert [image.image_clip_x, image.image_clip_y, image.image_clip_width,
				image.image_clip_height] == [31.5, 31.5, 100.0, 39.0]
			tiles := resolved_background_gradient_tiles(command)
			assert tiles.len == 1
			assert tiles[0].x == 32 && tiles[0].y == 32 && tiles[0].width == 99 && tiles[0].height == 38
		} else {
			assert destination == LayoutRect{31, 31, 101, 40}
			assert resolved_background_gradient_tiles(command).len > 1
		}
		document.finalize()
	}
}

fn test_libweb_gradient_retains_its_translated_background_geometry() {
	mut document := html.parse_document('<!doctype html><style>
		div{width:99px;height:38px;border:1px solid #444;border-radius:10px;
		background:linear-gradient(red,blue)}
	</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.libweb)
	root := layout_document_typed_in_viewport(document, 800, 600)
	command := root.paint_commands().filter(it.kind == 'fill_gradient')[0]
	assert command.image().background_image_destination == none
}
