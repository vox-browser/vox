module fetch

import dom
import http

fn pikabu_header_request() &Request {
	mut request := Request.create()
	request.url_list = [dom.URL{ value: 'https://pikabu.ru/ajax/opaque' }]
	request.client_document_url = dom.URL{
		value: 'https://pikabu.ru/'
	}
	request.initiator_type = .xml_http_request
	return request
}

fn pikabu_header_response() &Response {
	mut response := Response.create()
	response.header_list.append(http.Header{ name: 'LLaSalBBubRRl', value: '1' })
	response.set_body_bytes('advert payload'.bytes())
	return response
}

fn test_response_header_gate_blocks_host_and_preloaded_bytes() {
	mut request := pikabu_header_request()
	params := FetchParams.create(request, FetchTimingInfo.create())
	host := FetchHost{
		perform: fn (_ &Request) !&Response {
			return pikabu_header_response()
		}
	}
	response := perform_host_fetch(params, request, host).response()?
	assert response.is_network_error()
	assert (response.network_error_message or { '' }).contains('responseheader=llasalbbubrrl')
	mut preload_params := FetchParams.create(pikabu_header_request(), FetchTimingInfo.create())
	preload_params.preloaded_response = pikabu_header_response()
	preloaded := main_fetch(preload_params, host).response()?
	assert preloaded.is_network_error()
	assert preloaded.body == none
}

fn test_response_header_gate_blocks_async_transport_and_cache_response_before_exposure() {
	mut request := pikabu_header_request()
	params := FetchParams.create(request, FetchTimingInfo.create())
	mut source := PendingResponse.create(mut request, none)
	host := FetchHost{
		perform:       fn (_ &Request) !&Response {
			return error('synchronous transport was used')
		}
		perform_async: fn [source] (_ &Request) &PendingResponse {
			return source
		}
	}
	pending := perform_host_fetch(params, request, host)
	assert !pending.is_resolved()
	source.resolve(pikabu_header_response())
	resolved := pending.response()?
	assert resolved.is_network_error()
	mut cached := pikabu_header_response()
	cached.cache_state = .local
	blocked := finish_http_network_or_cache_fetch(params, request, cached, false, false).response()?
	assert blocked.is_network_error()
	assert blocked.body == none
	mut ordinary := Response.create()
	ordinary.set_body_bytes('story payload'.bytes())
	assert request.apply_adblock_response(ordinary) == ordinary
}
