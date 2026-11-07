module main

import adblock
import css
import dom
import html
import platform

// Initial transport fetches preload bytes alongside blocking resources, but
// their link gets no active sheet until author code promotes its relationship.
// Queue completion after initial scripts have installed their load listeners.
fn (mut app BrowserApp) queue_initial_style_preload_completions(resources map[string]PreloadedResource) {
	mut storage := app.document.native_storage()
	mut allocations := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocations = storage.enter_nested() }
	persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
	defer {
		platform.leave_persistent(persistent)
		allocations.finish()
	}
	for link in css.query_selector_all(app.document.as_node(), 'link[rel][href]') {
		if !link_is_style_preload(link) { continue }
		address := resolve_document_reference(link.get_attribute_value('href'), app.document.base_url().serialize())
		resource := resources[address] or { continue }
		filtered := filter_preloaded_resource(resource, app.document.url.serialize(), 'stylesheet') or {
			PreloadedResource{ ...resource, error: err.msg(), body: '' }
		}
		retained := PreloadedResource{
			...filtered
			url:              filtered.url.clone()
			body:             filtered.body.clone()
			error:            filtered.error.clone()
			final_url:        filtered.final_url.clone()
			source_url:       filtered.source_url.clone()
			request_type:     filtered.request_type.clone()
			response_headers: filtered.response_headers.map(adblock.ResponseHeader{ name: it.name.clone(), value: it.value.clone() })
		}
		// Promotion consumes these same bytes through the ordinary stylesheet
		// completion path, without making a second request or creating a style tag.
		app.script_stylesheet_responses[address.clone()] = retained
		mut model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
		model.set_external_stylesheet_fetcher(true)
		document := app.document
		html.queue_a_task(.networking, none, document, fn [document, mut model, retained] () {
			mut storage := document.native_storage()
			mut allocations := platform.RetainedArenaScope{}
			if storage != unsafe { nil } { allocations = storage.enter_nested() }
			persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
			defer {
				platform.leave_persistent(persistent)
				allocations.finish()
			}
			address := if retained.final_url == '' { retained.url } else { retained.final_url }
			mut content_type := ''
			for header in retained.response_headers {
				if header.name.to_lower() == 'content-type' { content_type = header.value }
			}
			model.process_preload_response(retained.error == '', html.LinkResourceResponse{
				body:         retained.body.bytes()
				url:          dom.URL{ value: address }
				content_type: content_type
				origin_clean: dom.URL{ value: address }.origin().is_same_origin(document.origin())
			})
		})
	}
}
