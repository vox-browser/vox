@[has_globals]
module fetch

import dom
import http
import contentsecuritypolicy as csp

__global adblock_test_host_calls int

fn forbidden_adblock_transport(_ &Request) !&Response {
	adblock_test_host_calls++
	return error('blocked request reached transport')
}

fn adblock_redirect_transport(request &Request) !&Response {
	adblock_test_host_calls++
	assert request.current_url().serialize() == 'https://www.theverge.com/vox-adblock-fixture'
	mut response := Response.create()
	response.status = 302
	response.url_list = request.url_list.clone()
	response.header_list.append(http.Header{
		name:  'Location'
		value: 'https://www.google-analytics.com/g/collect?v=2'
	})
	return response
}

fn adblock_fixture_request(resource_url string) &Request {
	mut request := Request.create()
	request.url_list = [dom.URL{ value: resource_url }]
	request.client_document_url = dom.URL{
		value: 'https://www.theverge.com/article'
	}
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.URL{
			value: 'https://www.theverge.com/'
		}.origin()
	}
	request.initiator_type = .xml_http_request
	request.referrer = Referrer{
		sentinel: .no_referrer
	}
	return request
}

fn test_adblock_uses_document_owner_when_referrer_is_suppressed_and_after_clone() {
	mut request := adblock_fixture_request('https://www.google-analytics.com/g/collect?v=2')
	context := request.adblock_context()
	assert context.source_url == 'https://www.theverge.com/article'
	assert context.request_type == 'xmlhttprequest'
	request.destination = .font
	assert request.clone().adblock_context().request_type == 'font'
	request.destination = .iframe
	assert request.clone().adblock_context().request_type == 'sub_frame'
	request.mode = .websocket
	assert request.adblock_context().request_type == 'websocket'
}

fn test_adblock_prevents_preloaded_response_and_cors_preflight_from_bypassing_filters() {
	mut request := adblock_fixture_request('https://www.google-analytics.com/g/collect?v=2')
	request.method = 'PATCH'
	request.mode = .cors
	request.use_cors_preflight = true
	mut cached := Response.create()
	cached.set_body_bytes('cached tracker'.bytes())
	mut params := FetchParams.create(request, FetchTimingInfo.create())
	params.preloaded_response = cached
	adblock_test_host_calls = 0
	response := main_fetch(params, FetchHost{ perform: forbidden_adblock_transport }).response()?
	assert response.is_network_error()
	assert (response.network_error_message or { '' }).starts_with('Blocked by adblock:')
	assert adblock_test_host_calls == 0
}

fn test_adblock_rechecks_redirect_target_with_original_document_context() {
	mut request := adblock_fixture_request('https://www.theverge.com/vox-adblock-fixture')
	adblock_test_host_calls = 0
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: adblock_redirect_transport
	}).response()?
	assert response.is_network_error()
	assert (response.network_error_message or { '' }).starts_with('Blocked by adblock:')
	assert adblock_test_host_calls == 1
	assert request.adblock_context().source_url == 'https://www.theverge.com/article'
	assert request.redirect_count == 1
}

fn test_adblock_replacement_does_not_bypass_content_security_policy() {
	mut request := adblock_fixture_request('https://www.google-analytics.com/analytics.js')
	request.destination = .script
	request.resolved_policy_container = RequestPolicyContainer{
		csp_list: csp.PolicyList.create([
			csp.parse_a_serialized_csp("script-src 'none'", .header, .enforce),
		])
	}
	adblock_test_host_calls = 0
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: forbidden_adblock_transport
	}).response()?
	assert response.is_network_error()
	assert response.network_error_message? == 'Request was blocked'
	assert adblock_test_host_calls == 0
	global := request.csp_global or { panic('missing CSP violation record') }
	assert global.reports.len == 1
	assert global.reports[0].effective_directive == 'script-src-elem'
}
