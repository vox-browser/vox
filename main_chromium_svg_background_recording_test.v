module main

import encoding.base64
import dom
import html
import layout

fn svg_background_recording_test_command(svg string, repeat string) (layout.PaintCommand, &dom.Document) {
	address := 'data:image/svg+xml;base64,' + base64.encode_str(svg)
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:40px;height:24px;background:url("${address}") ${repeat};background-size:20px 12px}</style><div></div>')
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	for command in commands {
		if command.kind == 'draw_background_image' { return command, document }
	}
	panic('missing SVG background')
}

fn test_solid_svg_backgrounds_share_their_owning_picture_without_weakening_fallbacks() {
	for svg in [
		'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><circle cx="10" cy="6" r="4" fill="#c00"/></svg>',
		'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><path d="M2 2L18 6L2 10Z" fill="black" fill-opacity=".5"/></svg>',
	] {
		command, mut document := svg_background_recording_test_command(svg, 'no-repeat')
		defer { document.finalize() }
		assert chromium_svg_background_can_share_recording(&command)
		supported, vectors := chromium_shared_recording_leaf_supported(&command)
		assert supported && vectors
		for changed in [
			layout.PaintCommand{...command, opacity:.5},
			layout.PaintCommand{...command, group_opacity:.5},
			layout.PaintCommand{...command, image_data:&layout.PaintImageData{...command.image_data, image_attachment:'fixed'}},
			layout.PaintCommand{...command, image_data:&layout.PaintImageData{...command.image_data, background_blend_mode:.multiply}},
			layout.PaintCommand{...command, image_data:&layout.PaintImageData{...command.image_data, image_clip_width:0}},
			layout.PaintCommand{...command, image_data:&layout.PaintImageData{...command.image_data, image_clip_radii:layout.BoxRadii{top_left:layout.CornerRadius{4,4}}}},
		] {
			assert !chromium_svg_background_can_share_recording(&changed)
		}
	}
}

fn test_repeated_solid_svg_backgrounds_inspect_each_visible_tile() {
	for repeat in ['repeat', 'repeat-x', 'repeat-y', 'space', 'round'] {
		command, mut document := svg_background_recording_test_command('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><circle cx="10" cy="6" r="4" fill="#c00"/></svg>', repeat)
		defer { document.finalize() }
		assert chromium_svg_background_can_share_recording(&command)
		supported, vectors := chromium_shared_recording_leaf_supported(&command)
		assert supported && vectors
		too_many := layout.PaintCommand{...command,
			width: 2000, height: 2000,
			image_data:&layout.PaintImageData{...command.image_data, image_clip_width:2000, image_clip_height:2000}}
		if repeat == 'repeat' { assert !chromium_svg_background_can_share_recording(&too_many) }
	}
}

fn test_effectful_svg_backgrounds_keep_the_existing_recording_fallback() {
	for input in [
		['<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><g opacity=".5"><circle cx="10" cy="6" r="4"/></g></svg>', 'no-repeat'],
		['<svg xmlns="http://www.w3.org/2000/svg" width="20" height="12"><defs><linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><circle cx="10" cy="6" r="4" fill="url(#g)"/></svg>', 'repeat'],
	] {
		command, mut document := svg_background_recording_test_command(input[0], input[1])
		defer { document.finalize() }
		assert !chromium_svg_background_can_share_recording(&command)
	}
}
