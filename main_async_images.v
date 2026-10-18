module main

import browserjs
import browsernet
import adblock
import dom
import html

const max_browser_image_fetches = 8

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
	loader.queued = []BrowserImageFetchJob{}
	loader.pending.clear()
	loader.resources.clear()
}

fn (mut loader BrowserImageRequestLoader) start_queued_fetches() {
	for !loader.cancelled && loader.active_fetches < max_browser_image_fetches && loader.queued.len > 0 {
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

fn (mut loader BrowserImageRequestLoader) request(image &dom.HTMLImageElement,
	model &html.HTMLImageElementModel, address dom.URL, complete html.HTMLImageFetchCompletion) {
	if loader.cancelled { complete(none); return }
	if address.scheme() !in ['http', 'https'] {
		decoded := browser_fetch_image_request(image, model, address) or { complete(none); return }
		complete(decoded)
		return
	}
	if !browser_image_request_allows_cached_bytes(image, model, address) {
		complete(none)
		return
	}
	owner := unsafe { &dom.Element(image) }.document()
	source_url := owner.url.serialize()
	resource_url := address.serialize()
	key := source_url + '\n' + resource_url
	filtered := browsernet.filter(adblock.Request{url: resource_url, source_url: source_url, request_type: 'image'}) or {
		complete(none)
		return
	}
	if replacement := filtered.replacement {
		decoded := browser_decoded_image_data(address, replacement.body.bytes()) or { complete(none); return }
		complete(decoded)
		return
	}
	if voidptr(owner) == voidptr(loader.document) {
		if resource := loader.resources[resource_url] {
			if resource.request_type in ['', 'image'] && filtered.url == resource_url
				&& !resource.adblock_replacement
				&& (resource.error == '' || (resource.source_url == source_url && resource.request_type == 'image'))
				&& (resource.final_url in ['', resource_url] || resource.source_url == source_url) {
				if resource.error != '' { complete(none); return }
				filter_browser_response_headers(adblock.Request{
					url: if resource.final_url == '' { resource_url } else { resource.final_url }
					source_url: source_url
					request_type: 'image'
				}, resource.response_headers) or { complete(none); return }
				decoded := browser_decoded_image_data(address, resource.body.bytes()) or { complete(none); return }
				complete(decoded)
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
		decoded := browser_decoded_image_data(address, resource.body.bytes()) or { complete(none); return }
		complete(decoded)
		return
	}
	loader.pending[key] = [complete]
	loader.queued << BrowserImageFetchJob{url: resource_url, source_url: source_url}
	loader.start_queued_fetches()
}

fn (mut app BrowserApp) poll_browser_image_requests() {
	mut loader := app.image_request_loader or { return }
	if voidptr(loader.document) != voidptr(app.document) { return }
	mut completed := false
	for {
		select {
			resource := <-loader.results {
				loader.active_fetches--
				key := resource.source_url + '\n' + resource.url
				callbacks := loader.pending[key] or { continue }
				loader.pending.delete(key)
				mut decoded := ?html.DecodedImageData(none)
				if resource.error == '' {
					if address := dom.dom_url_parse(resource.url, loader.document.base_url(), 'UTF-8') {
						if data := browser_decoded_image_data(address, resource.body.bytes()) { decoded = data }
					}
					app.retain_navigation_resource(resource.url, resource)
				}
				for callback in callbacks { callback(decoded) }
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
		request_browser_frame()
	}
}
