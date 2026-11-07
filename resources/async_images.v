module main

import browserjs
import os
import browsernet
import adblock
import dom
import html
import platform
import painting

const max_browser_image_fetches = 8

// Diagnostic: VOX_TRACE_IMAGE_FAILURES=1 reports image fetches that complete
// without decoded pixels, with their transport error, so a broken image in a
// capture can be traced to its request.
const trace_image_failures = os.getenv('VOX_TRACE_IMAGE_FAILURES') != ''
// Same-binary control: leave synchronous disk-cache responses out of the
// shell's response cache, as before. Native replay then refetches JPEG/WebP
// pixels and repaints the whole document when they arrive.
const disable_image_disk_cache_retention = os.getenv('VOX_DISABLE_IMAGE_DISK_CACHE_RETENTION') != ''

fn trace_image_failure(url string, reason string) {
	if trace_image_failures { eprintln('Vox image request failed: ${url} ${reason}') }
}

fn (app &BrowserApp) can_load_images_asynchronously() bool {
	return !app.layout_tree_only && app.page_model != unsafe { nil }
}

struct BrowserImageFetchJob {
	url string
	source_url string
}

@[heap]
struct BrowserImageRequestLoader {
	document &dom.Document
	results chan PreloadedResource
mut:
	resources map[string]PreloadedResource
	pending map[string][]html.HTMLImageFetchCompletion
	load_event_pending bool
	queued []BrowserImageFetchJob
	active_fetches int
	cancelled bool
	cors_requests map[string]&BrowserCORSImageRequest
	cors_queued []&BrowserCORSImageRequest
	deferred_lazy_images []DeferredBrowserLazyImage
	lazy_image_queue_revision u64
	lazy_image_probe DeferredLazyImageProbe
	lazy_image_probe_offsets []painting.Point
	// Responses read synchronously from the disk cache, retained by the shell
	// on its next poll exactly like asynchronous completions.
	disk_cache_responses []PreloadedResource
}

fn new_browser_image_request_loader(document &dom.Document, resources map[string]PreloadedResource) &BrowserImageRequestLoader {
	types := document_preload_resource_types(document, document.base_url().serialize())
	mut images := map[string]PreloadedResource{}
	for address, resource in resources {
		if (types[address] or { 'image' }) == 'image' { images[address] = resource }
	}
	return &BrowserImageRequestLoader{
		document: document
		resources: images
		results: chan PreloadedResource{cap: max_cached_resources}
	}
}

fn (mut loader BrowserImageRequestLoader) finish_initialization(has_runtime bool) {
	loader.load_event_pending = has_runtime && loader.document.anything_is_delaying_the_load_event()
	// Initial responses, including failures and redirect bodies, only belong
	// to this installation. Later retries run the current request policy again.
	loader.resources = map[string]PreloadedResource{}
}

fn (mut loader BrowserImageRequestLoader) cancel() {
	loader.cancelled = true
	for _, request in loader.cors_requests { request.cancel() }
	loader.cors_requests = map[string]&BrowserCORSImageRequest{}
	loader.cors_queued = []&BrowserCORSImageRequest{}
	for request in loader.deferred_lazy_images {
		platform.release_closure(voidptr(request.complete))
	}
	loader.deferred_lazy_images = []DeferredBrowserLazyImage{}
	loader.lazy_image_queue_revision++
	loader.queued = []BrowserImageFetchJob{}
	for _, completions in loader.pending {
		for complete in completions { platform.release_closure(voidptr(complete)) }
	}
	loader.pending = map[string][]html.HTMLImageFetchCompletion{}
	loader.resources = map[string]PreloadedResource{}
	loader.disk_cache_responses = []PreloadedResource{}
}

// The loader owns each completion, a closure the image model made for one
// request: it is called once and then released.
fn finish_browser_image_request(complete html.HTMLImageFetchCompletion, decoded ?html.DecodedImageData) {
	complete(decoded)
	platform.release_closure(voidptr(complete))
}

fn (mut loader BrowserImageRequestLoader) start_queued_fetches() {
	for !loader.cancelled && loader.active_fetches < max_browser_image_fetches
		&& (loader.queued.len > 0 || loader.cors_queued.len > 0) {
		if loader.cors_queued.len > 0 {
			mut request := loader.cors_queued[0]
			loader.cors_queued.delete(0)
			request.start()
			continue
		}
		job := loader.queued[0]
		loader.queued.delete(0)
		loader.active_fetches++
		spawn fetch_navigation_preload(job.url, job.source_url, 'image', []PreloadedResource{}, loader.results)
	}
}

fn (loader &BrowserImageRequestLoader) callback() browserjs.ImageAsyncRequestFetchHook {
	return fn [loader] (image &dom.HTMLImageElement, model &html.HTMLImageElementModel,
		address dom.URL, complete html.HTMLImageFetchCompletion) {
		mut mutable_loader := unsafe { &BrowserImageRequestLoader(loader) }
		mutable_loader.request(image, model, address, complete)
	}
}

// Static documents use the same deduplication, cache, lazy-loading policy and
// document-owned completions as script-created images, without creating a VM.
fn (loader &BrowserImageRequestLoader) static_callback() html.HTMLImageModelAsyncFetchHook {
	return fn [loader] (model &html.HTMLImageElementModel, address dom.URL,
		complete html.HTMLImageFetchCompletion) {
		image := model.image_element() or { finish_browser_image_request(complete, none); return }
		mut owner := unsafe { &BrowserImageRequestLoader(loader) }
		owner.request(image, model, address, complete)
	}
}

fn (mut loader BrowserImageRequestLoader) request(image &dom.HTMLImageElement,
	model &html.HTMLImageElementModel, address dom.URL, complete html.HTMLImageFetchCompletion) {
	if loader.cancelled { finish_browser_image_request(complete, none); return }
	if voidptr(unsafe { &dom.Element(image) }.document()) == voidptr(loader.document)
		&& browser_lazy_image_needs_deferral(image) {
		if pending := model.pending_request() {
			loader.deferred_lazy_images << DeferredBrowserLazyImage{
				image: image
				model: model
				request: pending
				address: address
				complete: complete
			}
			loader.lazy_image_queue_revision++
			request_browser_frame_during_preparation()
			return
		}
	}
	loader.request_now(image, model, address, complete)
}

fn (mut loader BrowserImageRequestLoader) request_now(image &dom.HTMLImageElement,
	model &html.HTMLImageElementModel, address dom.URL, complete html.HTMLImageFetchCompletion) {
	if loader.cancelled { finish_browser_image_request(complete, none); return }
	if address.scheme() !in ['http', 'https'] {
		decoded := browser_fetch_image_request(image, model, address) or { finish_browser_image_request(complete, none); return }
		finish_browser_image_request(complete, decoded)
		return
	}
	if model.crossorigin() != .no_cors && loader.start_cors_image_request(image, model, address, complete) {
		return
	}
	if !browser_image_request_allows_cached_bytes(image, model, address) {
		trace_image_failure(address.serialize(), 'request policy rejected cached bytes')
		finish_browser_image_request(complete, none)
		return
	}
	owner := unsafe { &dom.Element(image) }.document()
	source_url := owner.url.serialize()
	resource_url := address.serialize()
	key := source_url + '\n' + resource_url
	filtered := browsernet.filter(adblock.Request{url: resource_url, source_url: source_url, request_type: 'image'}) or {
		trace_image_failure(resource_url, 'filter: ${err.msg()}')
		finish_browser_image_request(complete, none)
		return
	}
	if replacement := filtered.replacement {
		decoded := browser_decoded_image_data(address, replacement.body.bytes()) or { finish_browser_image_request(complete, none); return }
		finish_browser_image_request(complete, decoded)
		return
	}
	if voidptr(owner) == voidptr(loader.document) {
		if resource := loader.resources[resource_url] {
			if resource.request_type in ['', 'image'] && filtered.url == resource_url
				&& !resource.adblock_replacement
				&& (resource.error == '' || (resource.source_url == source_url && resource.request_type == 'image'))
				&& (resource.final_url in ['', resource_url] || resource.source_url == source_url) {
				if resource.error != '' {
					trace_image_failure(resource_url, 'initial response: ${resource.error}')
					finish_browser_image_request(complete, none)
					return
				}
				filter_browser_response_headers(adblock.Request{
					url: if resource.final_url == '' { resource_url } else { resource.final_url }
					source_url: source_url
					request_type: 'image'
				}, resource.response_headers) or { finish_browser_image_request(complete, none); return }
				decoded := browser_decoded_resource_image(address, resource) or {
					trace_image_failure(resource_url, 'initial response decode: ${err.msg()}')
					finish_browser_image_request(complete, none)
					return
				}
				finish_browser_image_request(complete, decoded)
				return
			}
		}
	}
	if key in loader.pending {
		loader.pending[key] << complete
		return
	}
	// This helper never performs network I/O, including for a cached redirect.
	// Available pixels keep their natural size in the very first layout.
	if resource := disk_cached_browser_resource(resource_url, source_url, 'image') {
		decoded := browser_decoded_resource_image(address, resource) or { finish_browser_image_request(complete, none); return }
		// JPEG, WebP and color-managed PNG pixels replay from the response bytes
		// rather than the decoded model. Without the response the first replay
		// requests this image again and repaints the whole document on arrival.
		if !disable_image_disk_cache_retention {
			persistent := platform.enter_persistent()
			loader.disk_cache_responses << persistent_preloaded_resource(resource)
			platform.leave_persistent(persistent)
		}
		finish_browser_image_request(complete, decoded)
		return
	}
	loader.pending[key] = [complete]
	loader.queued << BrowserImageFetchJob{url: resource_url, source_url: source_url}
	loader.start_queued_fetches()
}

// The loader can run inside a document or frame arena. A response it keeps for
// the shell's cache must outlive that scope; call inside a persistent entry.
fn persistent_preloaded_resource(resource PreloadedResource) PreloadedResource {
	mut headers := []adblock.ResponseHeader{cap: resource.response_headers.len}
	for header in resource.response_headers {
		headers << adblock.ResponseHeader{name: header.name.clone(), value: header.value.clone()}
	}
	return PreloadedResource{
		...resource
		url: resource.url.clone()
		body: resource.body.clone()
		error: resource.error.clone()
		source_url: resource.source_url.clone()
		final_url: resource.final_url.clone()
		request_type: resource.request_type.clone()
		response_headers: headers
	}
}

fn (mut app BrowserApp) poll_browser_image_requests() {
	mut loader := app.image_request_loader or { return }
	if voidptr(loader.document) != voidptr(app.document) { return }
	if loader.disk_cache_responses.len > 0 {
		persistent := platform.enter_persistent()
		for resource in loader.disk_cache_responses { app.retain_navigation_resource(resource.url, resource) }
		loader.disk_cache_responses = []PreloadedResource{}
		platform.leave_persistent(persistent)
	}
	mut completed := false
	// Selecting builds temporary channel lists even when no response is ready.
	// Producers buffer completions; a later frame polls anything arriving now.
	for loader.results.len > 0 {
		select {
			resource := <-loader.results {
				loader.active_fetches--
				key := resource.source_url + '\n' + resource.url
				callbacks := loader.pending[key] or { continue }
				loader.pending.delete(key)
				mut decoded := ?html.DecodedImageData(none)
				if resource.error == '' {
					if address := dom.dom_url_parse(resource.url, loader.document.base_url(), 'UTF-8') {
						if data := browser_decoded_resource_image(address, resource) { decoded = data }
					}
					app.retain_navigation_resource(resource.url, resource)
				}
				if decoded == none {
					trace_image_failure(resource.url, 'fetch: error=${resource.error} bytes=${resource.body.len}')
				}
				for callback in callbacks { finish_browser_image_request(callback, decoded) }
				completed = true
			}
			else { break }
		}
	}
	loader.start_queued_fetches()
	if loader.load_event_pending && !app.document.anything_is_delaying_the_load_event()
		&& app.js_runtime != unsafe { nil } {
		loader.load_event_pending = false
		app.js_runtime.dispatch_document_readiness_event('load') or {
			app.js_messages << 'JavaScript image load completion: ${err.msg()}'
		}
		app.js_runtime.mark_document_state_dirty()
	}
	if completed {
		app.paint_commands_pending = true
		app.request_document_frame()
	}
}
