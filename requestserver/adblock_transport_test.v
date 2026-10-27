module requestserver

import dom
import fetch
import http

fn test_blocked_direct_curl_request_never_creates_an_easy_handle() {
	$if !darwin { return }
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{ value: 'https://www.google-analytics.com/g/collect?v=2' }]
	request.client_document_url = dom.URL{
		value: 'https://www.theverge.com/'
	}
	request.initiator_type = .xml_http_request
	pending := connection.start_fetch(fetch.FetchParams.create(request,
		fetch.FetchTimingInfo.create()), request)
	assert pending.is_resolved()
	response := pending.response()?
	assert response.is_network_error()
	assert (response.network_error_message or { '' }).starts_with('Blocked by adblock:')
	assert connection.active_request_count() == 0
}

fn test_response_header_gate_rejects_curl_payload_before_receiver_delivery() {
	$if !darwin { return }
	mut connection := CurlConnection.create()!
	defer { connection.close() }
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{value: 'https://pikabu.ru/ajax/opaque'}]
	request.client_document_url = dom.URL{value: 'https://pikabu.ru/'}
	request.initiator_type = .xml_http_request
	params := fetch.FetchParams.create(request, fetch.FetchTimingInfo.create())
	pending := fetch.PendingResponse.create(mut request, none)
	body := fetch.Body.streaming()
	mut headers := http.HeaderList.create()
	headers.append(http.Header{name: 'LLaSalBBubRRl', value: ''})
	mut native := &CurlRequest{
		connection_: connection
		request_: request
		params_: params
		pending_: pending
		body_: body
		receiver_: fetch.FetchedDataReceiver.create(params, body.stream())
		easy_: C.curl_easy_init()
		response_headers_: headers
	}
	defer { native.stop() }
	bytes := 'advert payload'.bytes()
	assert curl_data_received(bytes.data, 1, uint(bytes.len), native) == 0
	response := pending.response()?
	assert response.is_network_error()
	assert (response.network_error_message or { '' }).contains('responseheader=llasalbbubrrl')
	assert native.adblock_blocked_
	assert body.stream().state() == .errored
}
