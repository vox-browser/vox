module fetch

import adblock
import dom
import http

// Filtering uses the owning document, not the Referer header, which may have
// been reduced or removed by referrer policy before a redirect is followed.
pub fn (request &Request) adblock_context() adblock.Request {
	mut source := ''
	if client := request.client {
		if document_url := client.fetch_request_client_document_url() {
			source = document_url.serialize()
		} else {
			source = client.fetch_request_client_creation_url().serialize()
		}
	} else if document_url := request.client_document_url {
		source = document_url.serialize()
	} else if creation_url := request.client_creation_url {
		source = creation_url.serialize()
	} else if referrer := request.referrer.url {
		source = referrer.serialize()
	} else if origin := request.origin.origin {
		if !origin.is_opaque() { source = origin.serialize() + '/' }
	}
	if source == '' { source = request.current_url().serialize() }
	mut request_type := 'other'
	if request.mode == .websocket {
		request_type = 'websocket'
	} else if destination := request.destination {
		request_type = match destination {
			.document {
				if request.target_is_nested_navigable { 'sub_frame' } else { 'main_frame' }
			}
			.frame, .iframe {
				'sub_frame'
			}
			.script, .json, .text, .worker, .service_worker, .shared_worker, .audio_worklet,
			.paint_worklet {
				'script'
			}
			.style, .xslt {
				'stylesheet'
			}
			.image {
				'image'
			}
			.font {
				'font'
			}
			.audio, .video, .track {
				'media'
			}
			.object, .embed {
				'object'
			}
			else {
				'other'
			}
		}
	} else if initiator := request.initiator_type {
		request_type = match initiator {
			.fetch, .xml_http_request { 'xmlhttprequest' }
			.beacon, .ping { 'ping' }
			else { 'other' }
		}
	}
	return adblock.Request{
		url:          request.current_url().serialize()
		source_url:   source
		request_type: request_type
		method:       request.method
	}
}

// Run before caches, preflights, and transport creation. Re-entering main_fetch
// after an HTTP redirect repeats this check with the original document owner.
pub fn (mut request Request) apply_adblock() ?&Response {
	if request.current_url().scheme() !in ['http', 'https', 'ws', 'wss'] { return none }
	for _ in 0 .. 8 {
		decision := adblock.check(request.adblock_context())
		if decision.error != '' {
			return Response.network_error('Adblock unavailable: ${decision.error}')
		}
		if decision.redirect_url != '' {
			if decision.redirect_url.starts_with('data:') {
				data := process_data_url(dom.URL{ value: decision.redirect_url }) or {
					return Response.network_error('Invalid adblock replacement resource')
				}
				mut response := Response.create()
				response.url_list = request.url_list.clone()
				response.header_list.append(http.Header{
					name:  'Content-Type'
					value: data.mime_type.serialized()
				})
				response.set_body_bytes(data.body)
				return response
			}
			if decision.redirect_url != request.current_url().serialize() {
				replacement := dom.dom_url_parse(decision.redirect_url, request.current_url(),
					'UTF-8') or { return Response.network_error('Invalid adblock request URL') }
				if replacement.scheme() !in ['http', 'https'] {
					return Response.network_error('Invalid adblock request URL scheme')
				}
				request.url_list[request.url_list.len - 1] = replacement
				continue
			}
		}
		if decision.blocked { return Response.network_error('Blocked by adblock: ${decision.rule}') }
		return none
	}
	return Response.network_error('Adblock request rewrite limit exceeded')
}

// Use raw internal headers, including repeated fields, before filtering the
// response for CORS/opaque exposure or inserting its bytes into a cache.
pub fn (request &Request) apply_adblock_response(response &Response) &Response {
	if response.is_network_error() { return response }
	internal := response.unsafe_response()
	mut headers := []adblock.ResponseHeader{}
	for header in internal.header_list.headers() {
		headers << adblock.ResponseHeader{name: header.name, value: header.value}
	}
	decision := adblock.check_response(request.adblock_context(), headers)
	if decision.error == '' && !decision.blocked { return response }
	if handle := internal.request_server_request() {
		if stop := handle.stop { stop() }
	}
	if mut body := internal.body {
		mut stream := body.stream()
		if stream.is_readable() { stream.error('TypeError: Blocked by adblock') }
	}
	return if decision.error != '' {
		Response.network_error('Adblock unavailable: ${decision.error}')
	} else {
		Response.network_error('Blocked by adblock: ${decision.rule}')
	}
}
