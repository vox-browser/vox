module layout

import html
import os

fn svg_auto_image_ratio_rects(chromium bool) map[string][]f64 {
	markup := os.read_file(os.join_path(@DIR, '..', 'Tests/Browser/Brave/input/engadget-svg-auto-image.html')) or { panic(err) }
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = run_document_layout(document, 1024, 768) or { panic('missing layout') }
	mut rects := map[string][]f64{}
	for id in ['cyclic', 'flex', 'auto', 'width', 'height', 'definite', 'raster'] {
		element := document.get_element_by_id(id) or { panic(id) }
		rect := element.get_bounding_client_rect()
		rects[id] = [rect.width, rect.height]
	}
	return rects
}

fn test_ratio_only_svg_image_percentage_height_transfers_the_used_block_size() {
	rects := svg_auto_image_ratio_rects(true)
	for id in ['cyclic', 'flex', 'auto'] {
		assert rects[id] == [134.921875, 27.984375], '${id}: ${rects[id]}'
	}
}

fn test_svg_image_ratio_transfer_preserves_authored_sizes_and_raster_images() {
	rects := svg_auto_image_ratio_rects(true)
	assert rects['width'] == [135.0, 27.984375]
	assert rects['height'] == [135.0, 28.0]
	assert rects['definite'] == [135.0, 28.0]
	assert rects['raster'] == [4.0, 4.0]
}

fn test_libweb_ratio_only_svg_image_keeps_the_upstream_automatic_width() {
	rects := svg_auto_image_ratio_rects(false)
	for id in ['cyclic', 'flex'] {
		assert rects[id] == [135.0, 27.984375], '${id}: ${rects[id]}'
	}
}
