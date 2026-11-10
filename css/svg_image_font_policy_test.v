// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module css

import dom
import fetch

// Ladybird 241fe045563c6ada5a055d9f2b83d600f429abfc. The engine-only
// file-font adapter must enforce the same policy as the browser Fetch host.
fn test_svg_image_file_fonts_never_reach_the_standalone_file_adapter() {
	for svg_image in [false, true] {
		mut document := dom.Document.create(dom.URL{value: 'https://svg-font.test/image.svg'})
		defer { document.finalize() }
		document.set_is_svg_image_document(svg_image)
		computer := FontComputer.create_for_document(document)
		assert computer.font_fetch_host() == none
		mut loader := FontLoader.create(computer, 'Isolated fixture', [], [
			URL.from_url('file:///missing-svg-image-policy-font.ttf'),
		], none)
		loader.start_loading_next_url()
		assert loader.has_completed
		assert loader.typeface == unsafe { nil }
		assert loader.has_started_request_ == !svg_image
	}
}

fn svg_image_font_forbidden_transport(_ &fetch.Request) !&fetch.Response {
	panic('a decoded SVG font must not reach the external transport')
}

fn test_svg_image_font_rejection_can_fall_through_to_an_allowed_data_source() {
	mut document := dom.Document.create(dom.URL{value: 'https://svg-font.test/image.svg'})
	defer { document.finalize() }
	document.set_is_svg_image_document(true)
	mut computer := FontComputer.create_for_document(document)
	computer.set_fetch_host(&fetch.FetchHost{perform: svg_image_font_forbidden_transport})
	mut loader := FontLoader.create(computer, 'Allowed fallback', [], [
		URL.from_url('https://external.test/blocked.ttf'),
		URL.from_url('data:application/octet-stream,not-a-font'),
	], none)
	loader.start_loading_next_url()
	// Invalid font bytes fail decoding, but their data response is consumed.
	assert loader.has_received_font_data_
	assert loader.has_completed
	assert loader.typeface == unsafe { nil }
	assert loader.urls.len == 0
}
