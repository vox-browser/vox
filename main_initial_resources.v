module main

import css
import dom

fn (mut app BrowserApp) preload_initial_document_resources(base_url string) map[string]PreloadedResource {
	mut cached := app.resource_cache.clone()
	for resource_url, resource in app.navigation_preloaded_resources {
		cached[resource_url] = resource
	}
	// Script and procedural-filter style reads may perform the first layout
	// during startup. Give them the same viewport as the eventual native frame.
	viewport_height := if app.viewport_height > 0 { app.viewport_height } else { initial_height - app.chrome_height() }
	app.document.set_viewport_rect(dom.Rect{
		width: if app.viewport_width > 0 { app.viewport_width } else { initial_width }
		height: viewport_height
	})
	// Script-enabled documents retain the existing capacity hint; HTML/CSS-only
	// documents let their managed heap grow with actual live state.
	_ = prepare_document_render_heap(app.document)
	if app.document.as_node().is_scripting_enabled() {
		types := document_preload_resource_types(app.document, base_url)
		// Images do not block scripts or the first document frame. Their native
		// request models consume cached bytes or complete on the owning thread.
		urls := document_preload_resource_urls(app.document, base_url).filter((types[it] or { 'image' }) != 'image')
		mut loaded := preload_document_resource_urls(app.document, base_url, urls, cached)
		for resource_url, resource in cached {
			if (types[resource_url] or { 'image' }) == 'image' { loaded[resource_url] = resource }
		}
		app.js_messages << install_external_styles(app.document, base_url, loaded)
		return loaded
	}
	urls := document_preload_resource_urls(app.document, base_url)
	types := document_preload_resource_types(app.document, base_url)
	mut style_urls := []string{}
	mut image_urls := []string{}
	for resource_url in urls {
		if (types[resource_url] or { 'image' }) == 'image' {
			image_urls << resource_url
		} else {
			style_urls << resource_url
		}
	}
	mut loaded := preload_document_resource_urls(app.document, base_url, style_urls, cached)
	app.js_messages << install_external_styles(app.document, base_url, loaded)
	// Media queries and author overrides must participate in the same cascade
	// used by layout before deciding whether an image has a display box.
	css.sync_document_style_elements(app.document)
	foreground, background := partition_nonrendered_image_preloads(app.document, base_url, image_urls)
	for resource_url in background {
		if resource := app.navigation_preloaded_resources[resource_url] {
			loaded[resource_url] = resource
			continue
		}
		app.request_background_resource(resource_url)
		if resource_url in app.background_resource_pending {
			app.nonrendered_image_preloads[resource_url] = true
		}
	}
	for resource_url, resource in preload_document_resource_urls(app.document, base_url, foreground, cached) {
		loaded[resource_url] = resource
	}
	return loaded
}
