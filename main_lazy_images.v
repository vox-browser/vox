module main

import dom
import html
import platform

struct DeferredBrowserLazyImage {
	image &dom.HTMLImageElement
	model &html.HTMLImageElementModel
	request &html.ImageRequest
	address dom.URL
	complete html.HTMLImageFetchCompletion
}

fn (request &DeferredBrowserLazyImage) is_current_for(document &dom.Document) bool {
	pending := request.model.pending_request() or { return false }
	return voidptr(pending) == voidptr(request.request)
		&& voidptr(unsafe { &dom.Element(request.image) }.document()) == voidptr(document)
}

fn browser_image_has_lazy_loading_policy(image &dom.HTMLImageElement) bool {
	element := unsafe { &dom.Element(image) }
	return element.as_node().is_scripting_enabled()
		&& element.get_attribute_value('loading').to_lower() == 'lazy'
}

fn browser_lazy_image_needs_deferral(image &dom.HTMLImageElement) bool {
	if !browser_image_has_lazy_loading_policy(image) { return false }
	element := unsafe { &dom.Element(image) }
	document := element.document()
	if !element.as_node().is_connected() || !document.layout_is_up_to_date()
		|| document.needs_style_update_after_layout() {
		return true
	}
	// Scrolling preserves layout but invalidates the retained scroll snapshot
	// used to transform client rectangles into viewport coordinates.
	mut owner := unsafe { &dom.Document(document) }
	owner.update_paint_and_hit_testing_properties_if_needed()
	return !script_image_is_near_viewport(element, document.viewport_rect().height)
}

fn (loader &BrowserImageRequestLoader) lazy_static_callback() html.HTMLImageModelAsyncFetchHook {
	return fn [loader] (model &html.HTMLImageElementModel, address dom.URL,
		complete html.HTMLImageFetchCompletion) {
		image := model.image_element() or { finish_browser_image_request(complete, none); return }
		mut owner := unsafe { &BrowserImageRequestLoader(loader) }
		owner.request(image, model, address, complete)
	}
}

fn (mut app BrowserApp) resume_deferred_lazy_image_requests() bool {
	mut loader := app.image_request_loader or { return false }
	if loader.cancelled || voidptr(loader.document) != voidptr(app.document)
		|| loader.deferred_lazy_images.len == 0 || !app.document.layout_is_up_to_date()
		|| app.document.needs_style_update_after_layout() {
		return false
	}
	// Animations can keep producing frames while every lazy image remains far
	// away. Keep the existing queue storage on those frames.
	mut needs_work := false
	for request in loader.deferred_lazy_images {
		if !request.is_current_for(loader.document)
			|| !browser_lazy_image_needs_deferral(request.image) {
			needs_work = true
			break
		}
	}
	if !needs_work { return false }
	// Detach the current batch: a load handler can replace a source, append an
	// image, or navigate and cancel this loader while a request completes.
	requests := loader.deferred_lazy_images
	loader.deferred_lazy_images = []DeferredBrowserLazyImage{}
	mut resumed := false
	for request in requests {
		if loader.cancelled {
			// Cancellation discards callbacks, like ordinary in-flight requests.
			platform.release_closure(voidptr(request.complete))
			continue
		}
		if !request.is_current_for(loader.document) {
			finish_browser_image_request(request.complete, none)
			continue
		}
		if browser_lazy_image_needs_deferral(request.image) {
			loader.deferred_lazy_images << request
			continue
		}
		loader.request_now(request.image, request.model, request.address, request.complete)
		resumed = true
	}
	return resumed
}
