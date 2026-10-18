module main

import css
import dom
import html

// Scripts insert images that the navigation preload never saw, such as 4chan's
// catalog thumbnails written through innerHTML. The parser gives them no fetch
// hook, so they never requested their bytes. After the DOM tree changes, fetch
// each new remote one in the background like a deferred image; its request
// completes from the fetched bytes instead of blocking on the network. Bytes
// the disk cache holds are read at once. Returns the resources that are
// already available.
fn (mut app BrowserApp) request_script_inserted_images() map[string]bool {
	mut ready := map[string]bool{}
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
			ready[resource_url] = true
			continue
		}
		if resource_url !in app.resource_cache && resource_url !in app.background_resource_pending
			&& app.resource_cache.len < max_cached_resources
			&& !resource_url.all_before('#').all_before('?').to_lower().ends_with('.svg') {
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
		bytes := app.background_image_bytes(resource_url) or { []u8{} }
		model.set_fetch_hook(fn [image, model, resource_url, bytes] (address dom.URL) !html.DecodedImageData {
			if address.serialize() != resource_url || !browser_image_request_allows_cached_bytes(image, model, address) {
				return browser_fetch_image_request(image, model, address)
			}
			if bytes.len == 0 {
				return error('Image request failed')
			}
			return browser_decoded_image_data(address, bytes)
		})
		model.update_the_image_data(false, false)
		updated = true
	}
	return updated
}
