module main

import css
import dom
import html

// Chromium starts loading a lazy image once it is this close to the viewport
// on a fast connection (LazyLoadImageDistanceThresholdPx).
const script_image_disk_read_distance = 1250.0

// Scripts insert images that the navigation preload never saw, such as 4chan's
// catalog thumbnails written through innerHTML. The parser gives them no fetch
// hook, so they never requested their bytes. After the DOM tree changes, fetch
// each new remote one in the background like a deferred image; its request
// completes from the fetched bytes instead of blocking on the network. While
// layout is current, the disk cache's bytes for an image laid out near the
// viewport are read at once, so the next paint shows it. Each read filters
// the request on the UI thread, so images further away stay in the
// background. Returns the resources that are already available; the list is
// empty (and allocates nothing) on frames where the DOM did not change.
fn (mut app BrowserApp) request_script_inserted_images() []string {
	mut ready := []string{}
	if app.document == unsafe { nil } || app.js_runtime == unsafe { nil } {
		return ready
	}
	version := app.document.dom_tree_version()
	if version == app.script_image_scan_version {
		return ready
	}
	app.script_image_scan_version = version
	base_url := app.document.base_url().serialize()
	source_url := app.document.url.serialize()
	// Reading geometry from a stale layout would lay the document out again.
	layout_is_current := app.document.layout_is_up_to_date()
		&& !app.document.needs_style_update_after_layout()
	if layout_is_current {
		mut document := unsafe { &dom.Document(app.document) }
		document.update_paint_and_hit_testing_properties_if_needed()
	}
	viewport_height := f64(if app.viewport_height > 0 { app.viewport_height } else { initial_height }) / app.page_zoom
	for element in css.query_selector_all(app.document.as_node(), 'img[src]') {
		if !element.is_html_element() {
			continue
		}
		model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		if model.has_fetch_hook() {
			continue
		}
		resource_url := resolve_document_reference(element.get_attribute_value('src'), base_url)
		if resource_url in app.script_image_requests {
			continue
		}
		if !resource_url.starts_with('http://') && !resource_url.starts_with('https://') {
			ready << resource_url
			continue
		}
		if app.request_lazy_script_inserted_image(element) {
			continue
		}
		if layout_is_current && resource_url !in app.resource_cache
			&& resource_url !in app.background_resource_pending
			&& app.resource_cache.len < max_cached_resources
			&& !resource_url.all_before('#').all_before('?').to_lower().ends_with('.svg')
			&& script_image_is_near_viewport(element, viewport_height) {
			if cached := disk_cached_browser_resource(resource_url, source_url, 'image') {
				app.resource_cache[resource_url] = cached
				ready << resource_url
				continue
			}
		}
		app.request_background_resource(resource_url)
		if resource_url in app.background_resource_pending {
			app.script_image_requests[resource_url] = true
		} else {
			ready << resource_url
		}
	}
	return ready
}

// A script-inserted image with the lazy-loading policy, such as each of
// 4chan's 201 catalog thumbnails, takes the document's image loader as its
// fetch hook. Like a parser-inserted image it then waits until it is laid out
// near the viewport and shares the loader's per-document fetch limit, instead
// of every thumbnail starting its own request at once. The burst made a
// proxied catalog wait for all 201 responses and could exhaust a server's
// connection backlog, leaving broken thumbnails.
fn (mut app BrowserApp) request_lazy_script_inserted_image(element &dom.Element) bool {
	image := unsafe { &dom.HTMLImageElement(element) }
	if !browser_image_has_lazy_loading_policy(image) {
		return false
	}
	loader := app.image_request_loader or { return false }
	if loader.cancelled || voidptr(loader.document) != voidptr(app.document)
		|| voidptr(element.document()) != voidptr(app.document) {
		return false
	}
	mut model := html.html_image_element_model_for_dom_element(image)
	model.set_model_async_fetch_hook(loader.static_callback())
	model.update_the_image_data(false, false)
	return true
}

// At most this many script-inserted images are read from the disk cache
// before a page's first layout.
const max_unsized_script_images_before_layout = 8

// An image without both width and height attributes can take its natural
// size, so its bytes can change the layout; 4chan's script-inserted banner is
// one. Before the first layout, which the other images' reads wait for, such
// an eager image completes from the disk cache or starts its request. Returns
// the resources that are already available.
fn (mut app BrowserApp) request_unsized_script_inserted_images() map[string]bool {
	mut ready := map[string]bool{}
	if app.document == unsafe { nil } || app.js_runtime == unsafe { nil } {
		return ready
	}
	base_url := app.document.base_url().serialize()
	source_url := app.document.url.serialize()
	mut candidates := 0
	for element in css.query_selector_all(app.document.as_node(), 'img[src]') {
		if !element.is_html_element() || (element.has_attribute('width') && element.has_attribute('height'))
			|| element.get_attribute_value('loading').to_lower() == 'lazy' {
			continue
		}
		model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		if model.has_fetch_hook() {
			continue
		}
		resource_url := resolve_document_reference(element.get_attribute_value('src'), base_url)
		if resource_url in app.script_image_requests || resource_url in ready
			|| (!resource_url.starts_with('http://') && !resource_url.starts_with('https://'))
			|| resource_url.all_before('#').all_before('?').to_lower().ends_with('.svg') {
			continue
		}
		if candidates == max_unsized_script_images_before_layout {
			break
		}
		candidates++
		if resource_url !in app.resource_cache && resource_url !in app.background_resource_pending
			&& app.resource_cache.len < max_cached_resources {
			if cached := disk_cached_browser_resource(resource_url, source_url, 'image') {
				app.resource_cache[resource_url] = cached
				ready[resource_url] = true
				continue
			}
		}
		app.request_background_resource(resource_url)
		if resource_url in app.background_resource_pending {
			app.script_image_requests[resource_url] = true
		} else {
			ready[resource_url] = true
		}
	}
	return ready
}

// A completed script-inserted image decodes the bytes its background request
// fetched; any other URL is requested as usual.
fn browser_script_image_model_fetch(model &html.HTMLImageElementModel, address dom.URL) !html.DecodedImageData {
	image := model.image_element() or { return error('Image request has no element') }
	if address.serialize() != model.embedder_response_url()
		|| !browser_image_request_allows_cached_bytes(image, model, address) {
		return browser_fetch_image_request(image, model, address)
	}
	bytes := model.embedder_response_bytes()
	if bytes.len == 0 {
		return error('Image request failed')
	}
	return browser_decoded_image_data(address, bytes)
}

fn script_image_is_near_viewport(element &dom.Element, viewport_height f64) bool {
	rects := element.client_rects_assuming_layout_clean()
	if rects.len == 0 {
		return false
	}
	top := rects[0].y_
	bottom := top + rects[0].height_
	return top < viewport_height + script_image_disk_read_distance
		&& bottom > -script_image_disk_read_distance
}

// Give the hookless images that use the completed resources the browser fetch
// hook and update their image data. Returns whether any image was updated.
fn (mut app BrowserApp) complete_script_inserted_images(completed map[string]bool) bool {
	base_url := app.document.base_url().serialize()
	mut updated := false
	for element in css.query_selector_all(app.document.as_node(), 'img[src]') {
		if !element.is_html_element() {
			continue
		}
		image := unsafe { &dom.HTMLImageElement(element) }
		mut model := html.html_image_element_model_for_dom_element(image)
		if model.has_fetch_hook() {
			continue
		}
		resource_url := resolve_document_reference(element.get_attribute_value('src'), base_url)
		if resource_url !in completed {
			continue
		}
		// A failed fetch leaves the image broken rather than retrying it on
		// the UI thread.
		model.set_embedder_response(resource_url, app.background_image_bytes(resource_url) or { []u8{} })
		model.set_model_fetch_hook(browser_script_image_model_fetch)
		model.update_the_image_data(false, false)
		updated = true
	}
	return updated
}
