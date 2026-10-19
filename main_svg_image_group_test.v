module main

import dom
import layout
import os

fn test_simple_svg_images_share_recording_but_effects_keep_individual_replay() {
	markup := os.read_file(os.join_path(@DIR,
		'Tests/Browser/Brave/input/svg-image-non-scaling-stroke.html'))!
	mut document := parse_loaded_browser_navigation_document(LoadedPage{
		url:    'about:blank'
		markup: markup
	}, dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	mut app := BrowserApp{
		document: document
	}
	app.relayout(800, 712)
	images := app.paint_commands.filter(it.kind == 'paint_nested_display_list')
	assert images.len == 3
	paintable := images[1].nested_viewport_paintable?
	container := paintable.nested_layout_size?
	assert container.width == 80
	assert container.height == 86.328125
	assert paintable.nested_rect?.height == 86
	for image in images {
		assert chromium_svg_image_can_share_recording(image)
		assert !chromium_svg_image_can_share_recording(layout.PaintCommand{ ...image, opacity: .5 })
		mut commands := image.nested_viewport_commands.clone()
		commands[0] = layout.PaintCommand{
			...commands[0]
			kind: 'begin_css_effect_layer'
		}
		changed := layout.PaintCommand{
			...image
			nested_viewport_commands: commands
		}
		assert !chromium_svg_image_can_share_recording(changed)
	}
}
