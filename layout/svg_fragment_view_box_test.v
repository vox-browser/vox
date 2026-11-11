// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import dom
import html

fn test_svg_view_fragment_is_not_part_of_the_decoded_image_bytes() {
	mut document := html.parse_document('<!doctype html>')
	defer { document.finalize() }
	address := 'data:image/svg+xml,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20viewBox=%220%200%20100%20100%22/%3E#svgView(viewBox(0,0,80,40))'
	image_source := svg_image_source_for_source(document, address) or { panic('image source') }
	assert !image_source.source.contains('#svgView')
	assert image_source.url.fragment()? == 'svgView(viewBox(0,0,80,40))'
	intrinsic := image_intrinsic_size_for_source(document, address) or { panic('intrinsic size') }
	assert intrinsic.aspect_ratio?.to_double() == 2
	assert intrinsic.width == none && intrinsic.height == none
}

fn test_svg_fragment_view_boxes_drive_layout_and_natural_aspect_ratio() {
	mut embedder := html.parse_document('<!doctype html>')
	defer { embedder.finalize() }
	for fragment in ['svgView(viewBox(20,0,40,20))', 'named'] {
		mut document := parse_svg_image_document(SVGImageSource{
			source: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><view id="named" viewBox="20 0 40 20"/><rect x="20" width="40" height="20" fill="red"/></svg>'
			url: dom.URL{value: 'https://fragment.test/image.svg#${fragment}'}
		}, 'light', embedder) or { panic('missing SVG image') }
		defer { document.finalize() }
		assert svg_background_natural_size(document).aspect_ratio?.to_double() == 2
		_ = run_document_layout(document, 80, 40) or { panic('missing layout') }
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		paths := commands.filter(it.kind == 'draw_svg_path')
		assert paths.len == 1
		assert paths[0].svg().path_transform == [f64(2), 0, 0, 2, -40, 0]!
	}
}
