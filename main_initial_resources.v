module main

import css
import dom

fn (mut app BrowserApp) preload_initial_document_resources(base_url string) map[string]PreloadedResource {
	if app.document.as_node().is_scripting_enabled() {
		loaded := preload_document_resources(app.document, base_url, app.resource_cache)
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
	mut loaded := preload_document_resource_urls(app.document, base_url, style_urls, app.resource_cache)
	app.js_messages << install_external_styles(app.document, base_url, loaded)
	// Media queries and author overrides must participate in the same cascade
	// used by layout before deciding whether an image has a display box.
	viewport_height := if app.viewport_height > 0 { app.viewport_height } else { initial_height - app.chrome_height() }
	app.document.set_viewport_rect(dom.Rect{
		width: if app.viewport_width > 0 { app.viewport_width } else { initial_width }
		height: viewport_height
	})
	css.sync_document_style_elements(app.document)
	foreground, background := partition_nonrendered_image_preloads(app.document, base_url, image_urls)
	for resource_url in background {
		app.request_background_resource(resource_url)
		if resource_url in app.background_resource_pending {
			app.nonrendered_image_preloads[resource_url] = true
		}
	}
	for resource_url, resource in preload_document_resource_urls(app.document, base_url, foreground, app.resource_cache) {
		loaded[resource_url] = resource
	}
	return loaded
}
