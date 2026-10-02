module fetch

import dom

fn file_resource_request(origin ?dom.Origin, destination ?Destination) &Request {
	mut request := Request.create()
	request.url_list = [dom.URL{ value: 'file:///font.ttf' }]
	request.origin = RequestOrigin{
		is_client: false
		origin:    origin
	}
	request.destination = destination
	request.mode = .cors
	return request
}

fn file_resource_test_host() &FetchHost {
	return &FetchHost{
		perform: fn (request &Request) !&Response {
			mut response := Response.create()
			response.url_list = request.url_list.clone()
			response.set_body_bytes('resource'.bytes())
			return response
		}
	}
}

fn test_source_file_to_file_fonts_use_basic_tainting_despite_opaque_origins() {
	request := file_resource_request(dom.origin_create_opaque_file(), .font)
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()),
		file_resource_test_host()).response()?
	assert response.response_type == .basic
	assert response.fetch_response_body_bytes()? == 'resource'.bytes()
}

fn test_file_font_exception_preserves_other_cors_scheme_checks() {
	for request in [file_resource_request(dom.origin_create_opaque_file(), .script),
		file_resource_request(dom.origin_create_opaque(), .font),
		file_resource_request(dom.URL{ value: 'https://origin.test/' }.origin(), .font)] {
		response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()),
			file_resource_test_host()).response()?
		assert response.is_network_error()
	}
}

fn test_file_scheme_fetch_blocks_network_origins_missing_origins_and_empty_destinations() {
	for request in [file_resource_request(none, .font),
		file_resource_request(dom.URL{ value: 'https://origin.test/' }.origin(), .font),
		file_resource_request(dom.origin_create_opaque_file(), none)] {
		response := scheme_fetch(FetchParams.create(request, FetchTimingInfo.create()),
			file_resource_test_host()).response()?
		assert response.is_network_error()
		assert response.fetch_response_network_error_message()?.contains("'file:' or 'resource:'")
	}
}

fn test_file_scheme_fetch_allows_opaque_origin_browser_subresources() {
	for destination in [Destination.font, .script, .style, .image] {
		request := file_resource_request(dom.origin_create_opaque_file(), destination)
		response := scheme_fetch(FetchParams.create(request, FetchTimingInfo.create()),
			file_resource_test_host()).response()?
		assert !response.is_network_error()
	}
}
