module browsernet

import adblock
import browsercookies
import dom
import encoding.base64
import loader
import net
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
	// Largest response-body prefix delivered while the response was incomplete.
	// Buffered/cache responses have no such prefix. Image decoders use this
	// provenance to preserve an incremental RGB generator after completion.
	bytes_available_before_completion u64
	// Final hop timestamps, shared by every persistent-cache consumer.
	request_time i64
	response_time i64
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

fn fetch_with_timeout_recovery(config http.FetchConfig, mut progress ResponseBodyProgress) !http.Response {
	return http.fetch(config) or {
		// A stalled HTTP/2 stream need not mean the origin is unreachable.
		// Retry this GET once over HTTP/1, keeping TLS, proxy and redirect policy.
		// Other failures (including TLS validation) retain their original error.
		if config.method != .get || !config.enable_http2 || !config.url.starts_with('https://')
			|| err.code() != net.err_timed_out_code
			|| !err.msg().starts_with('h2: request timed out waiting for a response after ') {
			return err
		}
		// Partial bytes from the abandoned response cannot describe the retry's
		// image body, even if both responses happen to share the same prefix.
		progress.previous = 0
		progress.incomplete_prefix = 0
		progress.prefix.clear()
		http.fetch(http.FetchConfig{
			...config
			enable_http2: false
			max_retries: 1
		})!
	}
}

// net.http's automatic redirect mode does not retain the final URL and would
// hide redirect targets from the blocker. Resolve every hop explicitly while
// retaining the document and resource type of the original request.
pub fn get(input adblock.Request, ca_bundle string) !HTTPResult {
	scope := new_request_scope()
	defer { scope.release() }
	return get_resource(input, ca_bundle, scope, false)
}

// A navigation/document supplies its lifetime. The worker adapter can remove
// an active transfer even while the origin is not delivering progress events.
pub fn get_with_scope(input adblock.Request, ca_bundle string, scope &RequestScope) !HTTPResult {
	return get_resource(input, ca_bundle, scope, true)
}

fn get_resource(input adblock.Request, ca_bundle string, scope &RequestScope, cancellable bool) !HTTPResult {
	mut resource_url := input.url
	mut owns_slot := false
	defer { if owns_slot { release_request_slot() } }
	for hop in 0 .. 21 {
		scope.check()!
		filtered := filter(adblock.Request{
			url:          resource_url
			source_url:   input.source_url
			request_type: input.request_type
			method:       input.method
		})!
		resource_url = filtered.url
		scope.check()!
		if replacement := filtered.replacement { return HTTPResult{
				url:            resource_url
				response:       replacement
				is_replacement: true
			} }
		if !resource_url.starts_with('http://') && !resource_url.starts_with('https://') {
			return error('Unsupported URL scheme')
		}
		if !owns_slot {
			scope.acquire_request_slot()!
			owns_slot = true
		}
		// Both transports negotiate HTTP/2 with HTTP/1 fallback. The cancellable
		// worker owns its curl connection cache; legacy requests use net.http's pool.
		proxy := request_proxy(resource_url)!
		mut progress := &ResponseBodyProgress{}
		on_body := if input.request_type == 'image' && !cancellable {
			http.RequestProgressBodyFn(fn [mut progress] (_ &http.Request, chunk []u8,
				received u64, expected u64, status int) ! {
				progress.observe(chunk, received, expected, status)
			})
		} else { http.RequestProgressBodyFn(unsafe { nil }) }
		config := http.FetchConfig{
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
			on_progress_body: on_body
		}
		mut request_time := time.now().unix_milli()
		mut response_time := i64(0)
		response := if cancellable {
			result := fetch_cancellable(config, scope, mut progress)!
			request_time = result.request_time
			response_time = result.response_time
			result.response
		} else {
			result := fetch_with_timeout_recovery(config, mut progress)!
			response_time = time.now().unix_milli()
			result
		}
		scope.check()!
		filter_response(adblock.Request{
			url: resource_url
			source_url: input.source_url
			request_type: input.request_type
			method: input.method
		}, response)!
		// Keep each Set-Cookie field separate (Expires contains a comma), and
		// store redirect cookies before constructing the next hop's headers.
		scope.begin_publication()!
		browsercookies.store_response_cookies(resource_url, input.source_url,
			input.request_type == 'main_frame', 'GET', response.header.custom_values('Set-Cookie'))
		scope.end_publication()
		if response.status_code !in [301, 302, 303, 307, 308] {
			return HTTPResult{
				url:      resource_url
				response: response
				request_time: request_time
				response_time: response_time
				// Progress callbacks can precede content-coding decompression.
				// Only publish a prefix belonging to the returned body bytes.
				bytes_available_before_completion: if response.body.starts_with(progress.prefix.bytestr()) {
					progress.incomplete_prefix
				} else { 0 }
			}
		}
		location := response.header.get(.location) or {
			return HTTPResult{
				url:      resource_url
				response: response
				request_time: request_time
				response_time: response_time
			}
		}
		if location == '' { return HTTPResult{
				url:      resource_url
				response: response
				request_time: request_time
				response_time: response_time
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
