module layout

import html

fn chromium_box_fill(policy_chromium bool) PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#b{position:absolute;left:10.09375px;top:20.671875px;width:56px;height:44px;
		background:#36c;border-radius:2px}</style><div id="b"></div>')
	if policy_chromium {
		document.set_font_rendering_policy(.chromium)
	}
	mut root := layout_document_typed_in_viewport(document, 200, 100)
	return root.paint_commands().filter(it.kind == 'fill_rect' && it.radius == 2)[0]
}

// Brave paints the search button's background from its pixel-snapped border
// box, so a box at y=20.67px starts on a whole pixel instead of a blended row.
fn test_chromium_box_backgrounds_use_the_pixel_snapped_border_box() {
	blink := chromium_box_fill(true)
	assert blink.x == 10 && blink.y == 21 && blink.width == 56 && blink.height == 44
	libweb := chromium_box_fill(false)
	assert libweb.x == 10.09375 && libweb.y == 20.671875
}
