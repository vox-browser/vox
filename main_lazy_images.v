module main

import dom
import html
import layout
import os
import painting
import platform

const disable_lazy_image_probe_cache = os.getenv('VOX_DISABLE_LAZY_IMAGE_PROBE_CACHE') != ''
const disable_lazy_image_batches = os.getenv('VOX_DISABLE_LAZY_IMAGE_BATCHES') != ''
const lazy_image_batch_diagnostics = os.getenv('VOX_LAZY_IMAGE_BATCH_DIAGNOSTICS') != ''
const lazy_image_probe_diagnostics = os.getenv('VOX_LAZY_IMAGE_PROBE_DIAGNOSTICS') != ''

struct DeferredLazyImageProbe {
	valid bool
	queue_revision u64
	queue_length int
	tree_version u64
	style_version u64
	paint_revision u64
	paint_generation u64
	scroll_offsets []painting.Point
	viewport dom.Rect
}

fn (loader &BrowserImageRequestLoader) lazy_image_probe_matches(key DeferredLazyImageProbe) bool {
	if !loader.lazy_image_probe.valid || loader.lazy_image_probe != key { return false }
	// A model can abort or replace its pending request without a DOM mutation.
	// Keep the cheap ownership check; only geometry/policy probing is cached.
	for request in loader.deferred_lazy_images {
		if !request.is_current_for(loader.document) { return false }
	}
	if lazy_image_probe_diagnostics { eprintln('Vox lazy image probe: reused negative result count=${key.queue_length}') }
	return true
}

fn (mut loader BrowserImageRequestLoader) cache_lazy_image_probe(key DeferredLazyImageProbe) {
	mut storage := loader.document.enter_native_storage()
	defer { storage.finish() }
	loader.lazy_image_probe_offsets.clear()
	loader.lazy_image_probe_offsets << key.scroll_offsets
	loader.lazy_image_probe = DeferredLazyImageProbe{...key, scroll_offsets: loader.lazy_image_probe_offsets}
}

fn (app &BrowserApp) deferred_lazy_image_probe(loader &BrowserImageRequestLoader) ?DeferredLazyImageProbe {
	if disable_lazy_image_probe_cache { return none }
	mut document := unsafe { &dom.Document(app.document) }
	// One refresh captures nested scrolling and compositor transforms too.
	// The cached negative result is usable only for this exact geometry.
	document.update_paint_and_hit_testing_properties_if_needed()
	result := layout.document_layout_result(document) or { return none }
	return DeferredLazyImageProbe{
		valid: true
		queue_revision: loader.lazy_image_queue_revision
		queue_length: loader.deferred_lazy_images.len
		tree_version: document.dom_tree_version()
		style_version: document.style_environment_version()
		paint_revision: document.paint_content_revision()
		paint_generation: app.paint_generation
		// Compare published offsets, rather than dirty notifications: animation
		// ticks can invalidate scroll state while every offset stays unchanged.
		scroll_offsets: result.scroll_state_snapshot.device_offsets
		viewport: document.viewport_rect()
	}
}

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

fn (app &BrowserApp) has_resumable_lazy_image_requests() bool {
	mut loader := app.image_request_loader or { return false }
	if loader.cancelled || voidptr(loader.document) != voidptr(app.document)
		|| loader.deferred_lazy_images.len == 0
		|| !app.document.layout_is_up_to_date()
		|| app.document.needs_style_update_after_layout() {
		return false
	}
	probe := app.deferred_lazy_image_probe(loader)
	if key := probe {
		if loader.lazy_image_probe_matches(key) { return false }
	}
	mut all_current := true
	for request in loader.deferred_lazy_images {
		if !request.is_current_for(loader.document) {
			all_current = false
			continue
		}
		if !browser_lazy_image_needs_deferral(request.image) {
			return true
		}
	}
	if all_current {
		if key := probe { loader.cache_lazy_image_probe(key) }
	}
	return false
}

fn (mut app BrowserApp) resume_deferred_lazy_image_requests() bool {
	mut loader := app.image_request_loader or { return false }
	if loader.cancelled || voidptr(loader.document) != voidptr(app.document)
		|| loader.deferred_lazy_images.len == 0 || !app.document.layout_is_up_to_date()
		|| app.document.needs_style_update_after_layout() {
		return false
	}
	probe := app.deferred_lazy_image_probe(loader)
	if key := probe {
		if loader.lazy_image_probe_matches(key) { return false }
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
	if !needs_work {
		if key := probe { loader.cache_lazy_image_probe(key) }
		return false
	}
	// Detach the current batch: a load handler can replace a source, append an
	// image, or navigate and cancel this loader while a request completes.
	requests := loader.deferred_lazy_images
	// Intersection notifications describe one committed geometry snapshot.
	// Select the whole nearby batch before a synchronous cached completion can
	// invalidate layout or move a sibling. Recheck request ownership below.
	mut eligible := []bool{}
	if !disable_lazy_image_batches {
		eligible = []bool{len: requests.len}
		mut count := 0
		for index, request in requests {
			eligible[index] = request.is_current_for(loader.document)
				&& !browser_lazy_image_needs_deferral(request.image)
			if eligible[index] { count++ }
		}
		if lazy_image_batch_diagnostics {
			eprintln('Vox lazy image batch: eligible=${count} queued=${requests.len}')
		}
	}
	loader.deferred_lazy_images = []DeferredBrowserLazyImage{}
	loader.lazy_image_queue_revision++
	mut resumed := false
	for index, request in requests {
		if loader.cancelled {
			// Cancellation discards callbacks, like ordinary in-flight requests.
			platform.release_closure(voidptr(request.complete))
			continue
		}
		if !request.is_current_for(loader.document) {
			finish_browser_image_request(request.complete, none)
			continue
		}
		deferred := if disable_lazy_image_batches {
			browser_lazy_image_needs_deferral(request.image)
		} else { !eligible[index] }
		if deferred {
			loader.deferred_lazy_images << request
			continue
		}
		loader.request_now(request.image, request.model, request.address, request.complete)
		resumed = true
	}
	return resumed
}
