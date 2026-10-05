@[has_globals]
module fetch

import dom
import http

__global (
	referrer_runtime_headers  []string
	referrer_runtime_redirect bool
)

fn referrer_runtime_host(request &Request) !&Response {
	referrer_runtime_headers << (request.header_list.get('Referer') or { '<absent>' })
	mut response := Response.create()
	if referrer_runtime_redirect && referrer_runtime_headers.len == 1 {
		response.status = 302
		response.header_list.append(http.Header{ name: 'Location', value: 'https://other.test/final' })
		response.header_list.append(http.Header{ name: 'Referrer-Policy', value: 'no-referrer' })
	}
	return response
}

fn make_referrer_runtime_request(target string, policy string) &Request {
	mut request := Request.create()
	request.url_list = [dom.URL{value: target}]
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.URL{value: target}.origin()
	}
	request.referrer = Referrer{
		url: dom.URL{value: 'https://user:secret@source.test/path?private=1#fragment'}
	}
	request.referrer_policy = policy
	request.cache_mode = .no_store
	return request
}

fn test_main_fetch_applies_referrer_policy_before_network_dispatch() {
	referrer_runtime_redirect = false
	for case in [
		['no-referrer', 'https://target.test/', '<absent>'],
		['origin', 'https://target.test/', 'https://source.test/'],
		['strict-origin', 'http://target.test/', '<absent>'],
		['same-origin', 'https://target.test/', '<absent>'],
		['same-origin', 'https://source.test/', 'https://source.test/path?private=1'],
		['strict-origin-when-cross-origin', 'https://target.test/', 'https://source.test/'],
		['unsafe-url', 'https://target.test/', 'https://source.test/path?private=1'],
	] {
		referrer_runtime_headers = []string{}
		request := make_referrer_runtime_request(case[1], case[0])
		response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
			perform: referrer_runtime_host
		}).response()?
		assert !response.is_network_error()
		assert referrer_runtime_headers == [case[2]]
	}
}

fn test_main_fetch_uses_policy_container_default_and_client_referrer() {
	referrer_runtime_headers = []string{}
	referrer_runtime_redirect = false
	mut request := make_referrer_runtime_request('https://target.test/', '')
	request.referrer = Referrer{}
	request.client_is_window = true
	request.client_document_url = dom.URL{value: 'https://source.test/document#secret'}
	request.resolved_policy_container = RequestPolicyContainer{
		referrer_policy: 'origin'
	}
	main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: referrer_runtime_host
	})
	assert referrer_runtime_headers == ['https://source.test/']
}

fn test_redirect_reapplies_referrer_policy_without_expanding_referrer() {
	referrer_runtime_headers = []string{}
	referrer_runtime_redirect = true
	request := make_referrer_runtime_request('https://source.test/start', 'unsafe-url')
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: referrer_runtime_host
	}).response()?
	assert !response.is_network_error()
	assert referrer_runtime_headers == ['https://source.test/path?private=1', '<absent>']
	assert request.referrer.sentinel == .no_referrer
	assert request.referrer.url == none
}
