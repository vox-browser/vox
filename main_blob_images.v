module main

import dom
import fetch
import html

// Blob images use the owning document's Fetch client, including its policy
// container and storage partition. They never enter the HTTP byte cache.
fn browser_fetch_blob_image(element &dom.HTMLImageElement, model &html.HTMLImageElementModel,
	address dom.URL) !html.DecodedImageData {
	document := unsafe { &dom.Element(element) }.document()
	handle := document.relevant_settings_object()
	if handle == unsafe { nil } { return error('Blob image requires its owning settings') }
	settings := unsafe { &html.EnvironmentSettingsObject(handle) }
	mut selected := address
	if record := address.parsed() {
		if record.blob_url_entry() == none {
			// Serialized shell URLs have no Blob entry. Finish the actual URL
			// parse at request creation; retain an existing parsed snapshot.
			selected = settings.parse_url(address.serialize()) or { return error('Invalid Blob image URL') }
		}
	}
	mut request := fetch.Request.create()
	request.set_url(selected)
	request.set_client(settings)
	request.destination = .image
	request.mode = if model.crossorigin() == .no_cors { .no_cors } else { .cors }
	request.credentials_mode = if model.crossorigin() == .anonymous { .same_origin } else { .include }
	fetch.populate_request_from_client(mut request)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()),
		fetch.FetchHost{perform: fn (_ &fetch.Request) !&fetch.Response {
			return error('Blob image cannot use a network transport')
		}}).response() or { return error('Blob image response is not available') }
	if response.is_network_error() {
		return error(response.network_error_message or { 'Blob image fetch failed' })
	}
	internal := response.unsafe_response()
	body := internal.body or { return error('Blob image response has no body') }
	bytes := body.bytes()
	mime := (internal.header_list.get('Content-Type') or { '' }).all_before(';').trim_space().to_lower()
	decoded := if mime == 'image/svg+xml' {
		browser_decode_svg_image(selected, bytes)!
	} else {
		browser_decoded_image_data(selected, bytes)!
	}
	decoded.set_is_cors_cross_origin(response.response_type == .opaque)
	return decoded
}
