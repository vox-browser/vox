@[has_globals]
module fetch

import dom
import http

__global (
	redirect_referrer_source_headers []http.Header
	redirect_referrer_sent_headers   []string
)

fn redirect_referrer_source_host(request &Request) !&Response {
	redirect_referrer_sent_headers << (request.header_list.get('Referer') or { '<absent>' })
	mut response := Response.create()
	if redirect_referrer_sent_headers.len == 1 {
		response.status = 302
		response.header_list.append(http.Header{'Location', 'https://other.test/final'})
		for header in redirect_referrer_source_headers {
			response.header_list.append(header)
		}
	}
	return response
}

fn redirect_referrer_source_request(headers []http.Header) !&Request {
	redirect_referrer_source_headers = headers.clone()
	redirect_referrer_sent_headers = []string{}
	mut request := Request.create()
	request.url_list = [dom.URL{'https://source.test/start'}]
	request.origin = RequestOrigin{
		is_client: false
		origin:    dom.URL{'https://source.test/start'}.origin()
	}
	request.referrer = Referrer{
		url: dom.URL{'https://user:secret@source.test/path?private=1#fragment'}
	}
	request.referrer_policy = 'unsafe-url'
	request.cache_mode = .no_store
	response := main_fetch(FetchParams.create(request, FetchTimingInfo.create()), FetchHost{
		perform: redirect_referrer_source_host
	}).response() or { return error('redirect did not complete') }
	assert !response.is_network_error()
	assert request.redirect_count == 1
	assert request.current_url().serialize() == 'https://other.test/final'
	return request
}

fn test_source_redirect_keeps_a_raw_comma_value_invalid() {
	request := redirect_referrer_source_request([
		http.Header{'Referrer-Policy', 'origin, no-referrer'},
	])!
	assert request.referrer_policy == 'unsafe-url'
	assert redirect_referrer_sent_headers == ['https://source.test/path?private=1',
		'https://source.test/path?private=1']
}

fn test_source_redirect_uses_ascii_case_insensitive_policy_tokens() {
	request := redirect_referrer_source_request([
		http.Header{'rEfErReR-pOlIcY', 'NO-REFERRER'},
	])!
	assert request.referrer_policy == 'no-referrer'
	assert redirect_referrer_sent_headers == ['https://source.test/path?private=1', '<absent>']
}

fn test_source_redirect_preserves_repeated_header_order_and_last_valid_policy() {
	request := redirect_referrer_source_request([
		http.Header{'Referrer-Policy', 'origin'},
		http.Header{'referrer-policy', 'SAME-ORIGIN'},
		http.Header{'REFERRER-POLICY', 'invalid'},
		http.Header{'Referrer-Policy', ''},
	])!
	assert request.referrer_policy == 'same-origin'
	assert redirect_referrer_sent_headers == ['https://source.test/path?private=1', '<absent>']
}

fn test_source_redirect_does_not_trim_a_later_raw_policy_value() {
	request := redirect_referrer_source_request([
		http.Header{'Referrer-Policy', 'origin'},
		http.Header{'Referrer-Policy', ' \tno-referrer\t '},
	])!
	assert request.referrer_policy == 'origin'
	assert redirect_referrer_sent_headers == ['https://source.test/path?private=1',
		'https://source.test/']
}

fn test_source_redirect_preserves_policy_when_no_nonempty_valid_header_exists() {
	for headers in [
		[]http.Header{},
		[http.Header{'Referrer-Policy', ''}],
		[http.Header{'Referrer-Policy', 'invalid'}],
	] {
		request := redirect_referrer_source_request(headers)!
		assert request.referrer_policy == 'unsafe-url'
		assert redirect_referrer_sent_headers == ['https://source.test/path?private=1',
			'https://source.test/path?private=1']
	}
}
