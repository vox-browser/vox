// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import html
import painting

// Ladybird 39f6564d4605bc765f4803ed78a46c0ba527c4bd.
fn test_svg_image_preserve_aspect_ratio_controls_raster_image_fitting() {
	for index, value in ['none', 'xMinYMin meet', 'xMidYMid meet', 'xMaxYMax meet',
		'xMinYMin slice', 'xMidYMid slice', 'xMaxYMax slice', 'invalid'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{display:block}</style>
			<svg width="100" height="100"><image id="image" width="100" height="100" href="https://image-fit.test/image.png"
			preserveAspectRatio="${value}" style="object-fit:fill;object-position:0% 0%"/></svg>')
		defer { document.finalize() }
		root := layout_document_typed_in_viewport(document, 200, 200)
		image := root.paint_commands().filter(it.kind == 'draw_replaced_image')[0]
		paintable := image.image_paintable or { panic('missing image') }
		converter := painting.new_device_pixel_converter(1) or { panic(err) }
		painted := paintable.paint('test', painting.IntRect{0, 0, 200, 100}, converter) or { panic('missing paint') }
		expected := [
			painting.IntRect{0, 0, 100, 100},
			painting.IntRect{0, 0, 100, 50},
			painting.IntRect{0, 25, 100, 50},
			painting.IntRect{0, 50, 100, 50},
			painting.IntRect{0, 0, 200, 100},
			painting.IntRect{-50, 0, 200, 100},
			painting.IntRect{-100, 0, 200, 100},
			painting.IntRect{0, 25, 100, 50},
		]
		assert painted.bitmap.destination == expected[index]
		assert painted.bitmap.clip_rect == painting.IntRect{0, 0, 100, 100}
		mut element := document.get_element_by_id('image') or { panic('missing image element') }
		element.set_attribute_value('preserveAspectRatio', 'none')
		updated := layout_document_typed_in_viewport(document, 200, 200).paint_commands().filter(it.kind == 'draw_replaced_image')[0]
		updated_paintable := updated.image_paintable or { panic('missing updated image') }
		assert updated_paintable.object_fit == .fill
	}
}

fn test_svg_image_preserve_aspect_ratio_controls_nested_svg_fitting() {
	for value in ['none', 'xMaxYMax meet', 'xMaxYMax slice'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{display:block}</style>
			<svg width="100" height="100"><image width="100" height="100" preserveAspectRatio="${value}"
			href="data:image/svg+xml,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%22200%22%20height=%22100%22%3E%3Crect%20width=%22200%22%20height=%22100%22%20fill=%22red%22/%3E%3C/svg%3E"/></svg>')
		defer { document.finalize() }
		root := layout_document_typed_in_viewport(document, 200, 200)
		nested := root.paint_commands().filter(it.kind == 'paint_nested_display_list')[0]
		if value == 'none' {
			assert nested.x == 0 && nested.y == 0 && nested.width == 100 && nested.height == 100
		} else if value.ends_with('meet') {
			assert nested.x == 0 && nested.y == 50 && nested.width == 100 && nested.height == 50
		} else {
			assert nested.x == -100 && nested.y == 0 && nested.width == 200 && nested.height == 100
		}
	}
}
