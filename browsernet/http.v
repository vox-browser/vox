module browsernet

import adblock
import dom
import encoding.base64
import loader
import net.http
import time
import url

pub struct FilteredRequest {
pub:
	url         string
	replacement ?http.Response
}

pub struct HTTPResult {
pub:
	url            string
	response       http.Response
	is_replacement bool
}

// Retain repeated values in their wire order; uBO examines the first
// matching field rather than Fetch's comma-combined value.
pub fn response_headers(response http.Response) []adblock.ResponseHeader {
	mut headers := []adblock.ResponseHeader{}
	mut seen := map[string]bool{}
	for name in response.header.keys() {
		lower := name.to_lower()
		if lower in seen { continue }
		seen[lower] = true
		for value in response.header.custom_values(name) {
			headers << adblock.ResponseHeader{name: name, value: value}
		}
	}
	return headers
}

pub fn filter_response(input adblock.Request, response http.Response) ! {
	decision := adblock.check_response(input, response_headers(response))
	if decision.error != '' { return error('Adblock unavailable: ${decision.error}') }
	if decision.blocked { return error('Blocked by adblock: ${decision.rule}') }
}

fn request_user_agent(resource_url string) string {
	// Initial navigation may precede ResourceLoader initialization. Once the
	// loader exists, share navigator.userAgent's configuration and site rules.
	if loader.ResourceLoader.is_initialized() {
		return loader.ResourceLoader.the().user_agent_for_url(dom.URL{value: resource_url})
	}
	return loader.default_user_agent()
}

// This same gate is used before reading the browser's disk cache. In
// particular, a previously cached tracking script must never bypass filtering.
pub fn filter(input adblock.Request) !FilteredRequest {
	mut resource_url := input.url
	for _ in 0 .. 8 {
		decision := adblock.check(adblock.Request{
			url:          resource_url
			source_url:   input.source_url
			request_type: input.request_type
			method:       input.method
		})
		if decision.error != '' { return error('Adblock unavailable: ${decision.error}') }
		if decision.redirect_url != '' {
			if decision.redirect_url.starts_with('data:') {
				return FilteredRequest{
					url:         resource_url
					replacement: data_response(decision.redirect_url)!
				}
			}
			if decision.redirect_url != resource_url {
				if !decision.redirect_url.starts_with('https://')
					&& !decision.redirect_url.starts_with('http://') {
					return error('Invalid adblock request URL scheme')
				}
				resource_url = decision.redirect_url
				continue
			}
		}
		if decision.blocked { return error('Blocked by adblock: ${decision.rule}') }
		return FilteredRequest{
			url: resource_url
		}
	}
	return error('Adblock request rewrite limit exceeded')
}

fn data_response(resource_url string) !http.Response {
	comma := resource_url.index(',') or { return error('Invalid adblock replacement resource') }
	metadata := resource_url['data:'.len..comma]
	body := if metadata.to_lower().ends_with(';base64') {
		base64.decode(url.percent_decode(resource_url[comma + 1..]).bytestr()).bytestr()
	} else {
		url.percent_decode(resource_url[comma + 1..]).bytestr()
	}
	mime_type := metadata.all_before(';')
	return http.Response{
		status_code: 200
		status_msg:  'OK'
		body:        body
		header:      http.new_header(
			key:   .content_type
			value: if mime_type == '' { 'text/plain' } else { mime_type }
		)
	}
}

// net.http's automatic redirect mode does not retain the final URL and would
// hide redirect targets from the blocker. Resolve every hop explicitly while
// retaining the document and resource type of the original request.
pub fn get(input adblock.Request, ca_bundle string) !HTTPResult {
	mut resource_url := input.url
	for hop in 0 .. 21 {
		filtered := filter(adblock.Request{
			url:          resource_url
			source_url:   input.source_url
			request_type: input.request_type
			method:       input.method
		})!
		resource_url = filtered.url
		if replacement := filtered.replacement { return HTTPResult{
				url:            resource_url
				response:       replacement
				is_replacement: true
			} }
		if !resource_url.starts_with('http://') && !resource_url.starts_with('https://') {
			return error('Unsupported URL scheme')
		}
		// Share ALPN-negotiated HTTP/2 connections across concurrent resources.
		// HTTP/1 servers keep the same fallback and per-hop filtering above.
		proxy := request_proxy(resource_url)!
		response := http.fetch(
			url:            resource_url
			proxy:          if proxy == '' { unsafe { nil } } else { http.new_http_proxy(proxy)! }
			method:         .get
			header:         resource_request_headers(resource_url, input.source_url, input.request_type)
			user_agent:     request_user_agent(resource_url)
			enable_http2:   true
			allow_redirect: false
			read_timeout:   10 * time.second
			write_timeout:  10 * time.second
			validate:       true
			verify:         ca_bundle
		)!
		filter_response(adblock.Request{
			url: resource_url
			source_url: input.source_url
			request_type: input.request_type
			method: input.method
		}, response)!
		if response.status_code !in [301, 302, 303, 307, 308] {
			return HTTPResult{
				url:      resource_url
				response: response
			}
		}
		location := response.header.get(.location) or {
			return HTTPResult{
				url:      resource_url
				response: response
			}
		}
		if location == '' { return HTTPResult{
				url:      resource_url
				response: response
			} }
		if hop == 20 { return error('Maximum number of redirects reached (20)') }
		base_url := url.parse(resource_url) or { return error('Invalid request URL') }
		redirect_url := url.parse_with_base(location, base_url) or {
			return error('Invalid redirect URL')
		}
		resource_url = redirect_url.serialize(false)
	}
	return error('Maximum number of redirects reached (20)')
}
