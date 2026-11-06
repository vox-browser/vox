module main

import dom
import fetch
import html
import platform
import referrerpolicy
import requestserver

// The legacy encoded-byte cache has no CORS request identity. CORS-mode
// images use Fetch, which owns Origin, credentials, redirects and response
// validation instead of approving pixels from an unverified cache entry.
@[heap]
struct BrowserCORSImageRequest {
	loader  &BrowserImageRequestLoader
	key     string
	address dom.URL
	request &fetch.Request
	host    &fetch.FetchHost
	policy  &dom.PolicyContainer
mut:
	completions []html.HTMLImageFetchCompletion
	controller  ?&fetch.FetchController
	started     bool
	finished    bool
}

fn (mut loader BrowserImageRequestLoader) start_cors_image_request(image &dom.HTMLImageElement,
	model &html.HTMLImageElementModel, address dom.URL, complete html.HTMLImageFetchCompletion) bool {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	element := unsafe { &dom.Element(image) }
	settings_pointer := element.document().relevant_settings_object()
	if settings_pointer == unsafe { nil } { return false }
	policy := referrerpolicy.from_string(element.get_attribute('referrerpolicy') or { '' }) or { dom.ReferrerPolicy.empty_string }
	policy_text := referrerpolicy.to_string(policy)
	settings := unsafe { &html.EnvironmentSettingsObject(settings_pointer) }
	container := settings.policy_container()
	effective_policy := if policy == .empty_string { container.referrer_policy } else { policy }
	// Meta CSP can append a policy without replacing the container. Retain the
	// container and include its list length so a later blocked request cannot
	// join a fetch started under the document's earlier policy.
	key := '${element.document().unique_id()}\n${element.document().url.serialize()}\n${voidptr(container)}:${container.csp_list.len}\n${model.crossorigin()}\n${referrerpolicy.to_string(effective_policy)}\n${address.serialize()}'
	if mut pending := loader.cors_requests[key] {
		pending.completions << complete
		return true
	}
	host := requestserver.native_resource_fetch_host() or { return false }
	mut request := fetch.Request.create()
	request.set_client(settings)
	request.url_list = [address]
	request.destination = .image
	request.initiator_type = .img
	request.mode = .cors
	request.credentials_mode = if model.crossorigin() == .use_credentials {
		.include
	} else {
		.same_origin
	}
	request.use_url_credentials = true
	request.referrer_policy = policy_text
	pending := &BrowserCORSImageRequest{
		loader:      &loader
		key:         key
		address:     address
		request:     request
		host:        host
		policy:      container
		completions: [complete]
	}
	loader.cors_requests[key] = pending
	loader.cors_queued << pending
	loader.start_queued_fetches()
	return true
}

fn (mut pending BrowserCORSImageRequest) start() {
	if pending.finished || pending.started { return }
	pending.started = true
	mut loader := unsafe { &BrowserImageRequestLoader(pending.loader) }
	loader.active_fetches++
	owner := voidptr(&pending)
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response_consume_body: fn [owner] (response &fetch.Response, bytes fetch.BodyBytes) {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut current := unsafe { &BrowserCORSImageRequest(owner) }
			current.finish(response, bytes)
		}
	})
	mut controller := fetch.fetch(pending.request, algorithms, pending.host, .no)
	if pending.finished { controller.stop_fetch() } else { pending.controller = controller }
}

fn (mut pending BrowserCORSImageRequest) cancel() {
	if pending.finished { return }
	pending.finished = true
	if pending.started {
		mut loader := unsafe { &BrowserImageRequestLoader(pending.loader) }
		loader.active_fetches--
		pending.started = false
	}
	if mut controller := pending.controller { controller.stop_fetch() }
	pending.controller = none
	for complete in pending.completions { platform.release_closure(voidptr(complete)) }
	pending.completions = []html.HTMLImageFetchCompletion{}
}

fn (mut pending BrowserCORSImageRequest) finish(response &fetch.Response, bytes fetch.BodyBytes) {
	if pending.finished { return }
	pending.finished = true
	pending.controller = none
	mut loader := unsafe { &BrowserImageRequestLoader(pending.loader) }
	loader.cors_requests.delete(pending.key)
	if pending.started {
		loader.active_fetches--
		pending.started = false
	}
	if loader.cancelled {
		for complete in pending.completions { platform.release_closure(voidptr(complete)) }
		pending.completions = []html.HTMLImageFetchCompletion{}
		return
	}
	mut result := ?html.DecodedImageData(none)
	if !response.is_network_error() && response.response_type !in [.opaque, .opaque_redirect] && bytes.kind == .bytes {
		address := response.url() or { pending.address }
		if mut decoded := browser_decoded_image_data(address, bytes.bytes) {
			// A successful CORS Fetch has checked every redirect and response.
			decoded.set_is_cors_cross_origin(false)
			result = decoded
		}
	}
	for complete in pending.completions {
		if loader.cancelled {
			platform.release_closure(voidptr(complete))
		} else {
			finish_browser_image_request(complete, result)
		}
	}
	pending.completions = []html.HTMLImageFetchCompletion{}
	loader.start_queued_fetches()
}
