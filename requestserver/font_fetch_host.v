// ResourceLoader's process-owned RequestServer boundary for FontComputer.
@[has_globals]
module requestserver

import css
import dom
import fetch
import os
import url as liburl

@[heap]
pub struct NativeFontFetchTransport {
mut:
	connection &CurlConnection
	closed     bool
}

__global native_font_fetch_transport_ ?&NativeFontFetchTransport

// The browser owns its persistent resource cache. Fetch still owns request
// filtering, CORS checks and completion on the document's task destination.
pub type NativeFontResponseCacheProvider = fn (&fetch.Request) ?&fetch.Response

__global native_font_response_cache_provider_ ?NativeFontResponseCacheProvider

pub fn install_native_font_response_cache_provider(provider ?NativeFontResponseCacheProvider) {
	native_font_response_cache_provider_ = provider
}

pub fn NativeFontFetchTransport.create() !&NativeFontFetchTransport {
	return &NativeFontFetchTransport{
		connection: CurlConnection.create()!
	}
}

pub fn (transport &NativeFontFetchTransport) fetch_host() &fetch.FetchHost {
	return &fetch.FetchHost{
		perform:                   fn (_ &fetch.Request) !&fetch.Response {
			return error('Font RequestServer transport requires asynchronous Fetch')
		}
		perform_async_with_params: fn [transport] (params &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
			mut connection := unsafe { &CurlConnection(transport.connection) }
			if !transport.closed {
				if provider := native_font_response_cache_provider_ {
					if response := provider(request) {
						mut mutable_request := unsafe { &fetch.Request(request) }
						pending := fetch.PendingResponse.create(mut mutable_request, none)
						connection.deferred_.deferred_invoke(fn [transport, pending, response] () {
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
				return connection.start_fetch(params, request)
			}
			// File resources are read by ResourceLoader rather than HTTP curl.
			// Preserve its deferred completion and the client's Fetch task queue.
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			connection.deferred_.deferred_invoke(fn [transport, request, pending] () {
				mut output := unsafe { &fetch.PendingResponse(pending) }
				if transport.closed {
					output.resolve(fetch.Response.network_error('RequestServer is currently unavailable'))
					return
				}
				parsed := liburl.parse(request.current_url().serialize()) or {
					output.resolve(fetch.Response.network_error(err.msg()))
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
	transport.connection.close()
}

fn native_font_fetch_host_for_document(_ &dom.Document) ?&fetch.FetchHost {
	if transport := native_font_fetch_transport_ { return transport.fetch_host() }
	return none
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
