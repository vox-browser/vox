module layout

import html
import math

fn test_short_inline_tag_normalizes_radii_against_the_complete_border_box() {
	for text in ['ai', 'a i a', '<span>ai</span>'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/23.2px "Helvetica Neue",Arial,sans-serif}
			a{font-size:10.56px;border:1px solid #d5d458;border-radius:5px;padding:0 .4em 1px}
		</style><a>${text}</a>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 240)
		borders := root.paint_commands().filter(it.kind == 'paint_uniform_border')
		assert borders.len == 1
		border := borders[0]
		assert border.corner_radii.top_left == CornerRadius{4.5, 4.5}
		assert border.corner_radii.bottom_right == CornerRadius{4.5, 4.5}
	}
}

fn test_inline_percentage_radius_uses_padding_and_the_whole_text_run() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:20px/24px "Courier New",monospace}
		a{border:1px solid #d5d458;border-radius:50%;padding:0 8px}
	</style><a id="tag">a i a</a>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 240)
	tag := document.get_element_by_id('tag')?
	box := tag.get_bounding_client_rect()
	borders := root.paint_commands().filter(it.kind == 'paint_uniform_border')
	assert borders.len == 1
	radius := borders[0].corner_radii.top_left
	// The percentage basis retains 78.015625px, while the painted border is
	// snapped to 78px. Its common overlap factor also scales the vertical
	// radius before the uniform border's half-width inset.
	assert box.width == 78.015625 && box.height == 25
	assert radius.x == 38.5
	assert math.abs(radius.y - 11.997496604919434) < 0.000001
}
