module requestserver

import dom
import fetch

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
