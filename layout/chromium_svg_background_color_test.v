module layout

import html

fn test_svg_background_color_keeps_its_ordinary_command_for_shared_native_replay() {
	mut document := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg"/>')
	defer { document.finalize() }
	radius := CornerRadius{10, 10}
	image := &PaintImageData{
		background_svg_document: document
		image_clip_width:        20
		image_clip_height:       20
		image_clip_radii:        BoxRadii{
			top_left:     radius
			top_right:    radius
			bottom_right: radius
			bottom_left:  radius
		}
	}
	mut commands := [PaintCommand{
		kind:   'fill_rect'
		color:  '#dadada'
		radius: 10
		width:  20
		height: 20
	}, PaintCommand{ kind: 'draw_background_image', image_data: image }]
	chromium_pair_background_image_color(mut commands)
	assert commands.len == 2
	assert commands[0].underlays_next
	assert commands[0].color == '#dadada'
	// Unsupported native recordings still replay this deferred fill normally.
	has_svg_document := commands[1].image_data.background_svg_document != none
	assert has_svg_document
}
