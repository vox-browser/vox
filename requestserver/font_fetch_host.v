// ResourceLoader's process-owned RequestServer boundary for FontComputer.
@[has_globals]
module requestserver

import css
import dom
import fetch
import os
import platform
import url as liburl

@[heap]
pub struct NativeFontFetchTransport {
mut:
	// Cached and file responses complete on this queue without libcurl.
	deferred   &platform.EventLoopPlugin = platform.EventLoopPlugin.new()
	connection ?&CurlConnection
	closed     bool
}

__global native_font_fetch_transport_ ?&NativeFontFetchTransport = none

// The browser owns its persistent resource cache. Fetch still owns request
// filtering, CORS checks and completion on the document's task destination.
pub type NativeFontResponseCacheProvider = fn (&fetch.Request) ?&fetch.Response

__global native_font_response_cache_provider_ ?NativeFontResponseCacheProvider = none

pub fn install_native_font_response_cache_provider(provider ?NativeFontResponseCacheProvider) {
	native_font_response_cache_provider_ = provider
}

pub fn NativeFontFetchTransport.create() !&NativeFontFetchTransport {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	return &NativeFontFetchTransport{}
}

// A connection initializes libcurl, which macOS maps with its TLS, HTTP/2,
// HTTP/3 and compression libraries on first use. Only network font requests
// need it; most documents make none, so create it with the first such request.
fn (mut transport NativeFontFetchTransport) ensure_connection() !&CurlConnection {
	if connection := transport.connection { return connection }
	connection := CurlConnection.create_pooled()!
	transport.connection = connection
	return connection
}

fn (mut transport NativeFontFetchTransport) deferred_network_error(mut request fetch.Request, message string) &fetch.PendingResponse {
	pending := fetch.PendingResponse.create(mut request, none)
	transport.deferred.deferred_invoke(fn [pending, message] () {
		mut output := unsafe { &fetch.PendingResponse(pending) }
		output.resolve(fetch.Response.network_error(message))
	})
	return pending
}

pub fn (transport &NativeFontFetchTransport) fetch_host() &fetch.FetchHost {
	return &fetch.FetchHost{
		perform:                   fn (_ &fetch.Request) !&fetch.Response {
			return error('Font RequestServer transport requires asynchronous Fetch')
		}
		perform_async_with_params: fn [transport] (params &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
			mut owner := unsafe { &NativeFontFetchTransport(transport) }
			if !transport.closed {
				if provider := native_font_response_cache_provider_ {
					if response := provider(request) {
						mut mutable_request := unsafe { &fetch.Request(request) }
						pending := fetch.PendingResponse.create(mut mutable_request, none)
						owner.deferred.deferred_invoke(fn [transport, pending, response] () {
							mut output := unsafe { &fetch.PendingResponse(pending) }
							output.resolve(if transport.closed {
								fetch.Response.network_error('RequestServer is currently unavailable')
							} else { response })
						})
						return pending
					}
				}
			}
			if request.current_url().scheme() != 'file' {
				mut network_request := unsafe { &fetch.Request(request) }
				if transport.closed && transport.connection == none {
					return owner.deferred_network_error(mut network_request, 'RequestServer is currently unavailable')
				}
				mut connection := owner.ensure_connection() or {
					return owner.deferred_network_error(mut network_request, 'RequestServer is currently unavailable: ${err.msg()}')
				}
				return connection.start_fetch(params, request)
			}
			// File resources are read by ResourceLoader rather than HTTP curl.
			// Preserve its deferred completion and the client's Fetch task queue.
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			owner.deferred.deferred_invoke(fn [transport, request, pending] () {
				mut output := unsafe { &fetch.PendingResponse(pending) }
				if transport.closed {
					output.resolve(fetch.Response.network_error('RequestServer is currently unavailable'))
					return
				}
				parsed := liburl.parse(request.current_url().serialize()) or {
					output.resolve(fetch.Response.network_error('Failed to parse the file URL'))
					return
				}
				bytes := os.read_bytes(liburl.percent_decode(parsed.serialize_path()).bytestr()) or {
					output.resolve(fetch.Response.network_error(err.msg()))
					return
				}
				mut response := fetch.Response.create()
				response.url_list = request.url_list.clone()
				response.set_body_bytes(bytes)
				output.resolve(response)
			})
			return pending
		}
	}
}

pub fn (mut transport NativeFontFetchTransport) close() {
	if transport.closed { return }
	transport.closed = true
	if mut connection := transport.connection { connection.close() }
}

// Test observation: whether a network request has created the curl connection.
fn (transport &NativeFontFetchTransport) has_connection() bool {
	return transport.connection != none
}

fn (transport &NativeFontFetchTransport) active_request_count() int {
	if connection := transport.connection { return connection.active_request_count() }
	return 0
}

// Share the process-owned ResourceLoader transport with other native Fetch
// consumers. Each request still carries its own document client and policy.
pub fn native_resource_fetch_host() ?&fetch.FetchHost {
	if transport := native_font_fetch_transport_ { return transport.fetch_host() }
	return none
}

fn native_font_fetch_host_for_document(_ &dom.Document) ?&fetch.FetchHost {
	return native_resource_fetch_host()
}

pub fn install_native_font_fetch_host() ! {
	if native_font_fetch_transport_ != none { return }
	native_font_fetch_transport_ = NativeFontFetchTransport.create()!
	css.install_font_fetch_host_provider(native_font_fetch_host_for_document)
}

pub fn close_native_font_fetch_host() {
	if mut transport := native_font_fetch_transport_ { transport.close() }
	native_font_fetch_transport_ = none
}
