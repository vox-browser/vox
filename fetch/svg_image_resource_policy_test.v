// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module fetch

import dom

fn svg_image_forbidden_transport(_ &Request) !&Response {
	panic('SVG image subresource reached the network transport')
}

// Ladybird 241fe045563c6ada5a055d9f2b83d600f429abfc.
fn test_decoded_svg_client_rejects_non_data_urls_before_transport_and_preload_reuse() {
	for address in ['https://svg.test/secret', 'http://svg.test/secret', 'file:///secret.svg', 'blob:https://svg.test/id', 'about:blank'] {
		mut request := Request.create()
		request.client_is_svg_image = true
		request.url_list = [dom.URL{value: address}]
		mut params := FetchParams.create(request, FetchTimingInfo.create())
		params.set_preloaded_response_candidate(PreloadedResponseCandidate{kind: .response, response: Response.create()})
		response := main_fetch(params, FetchHost{perform: svg_image_forbidden_transport}).response()?
		assert response.is_network_error()
		assert request.clone().client_is_svg_image
	}
}

fn test_decoded_svg_client_keeps_embedded_data_resources() {
	mut request := Request.create()
	request.client_is_svg_image = true
	request.url_list = [dom.URL{value: 'data:text/plain,embedded'}]
	request.mode = .no_cors
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{perform: svg_image_forbidden_transport}).response()?
	assert !response.is_network_error()
	assert response.fetch_response_body()?.bytes() == 'embedded'.bytes()
	request.clear_client()
	assert !request.client_is_svg_image
}
