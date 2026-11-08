module main

import dom
import css
import html
import platform
import layout

// Resource requests must not block the native event callback that commits a
// navigation. Discover them on the owning thread, then wait through the frame
// loop while the current document remains available for input and painting.
struct PendingPagePreload {
	loaded      LoadedPage
	add_history bool
	generation  int
	results     chan PreloadedResource
mut:
	remaining          int
	resources          map[string]PreloadedResource
	discovery_document &dom.Document = unsafe { nil }
	image_urls         []string
}

fn (mut app BrowserApp) cancel_page_preload() {
	if mut pending := app.pending_page_preload {
		if pending.discovery_document != unsafe { nil } { retire_native_preload_document(pending.discovery_document) }
	}
	app.pending_page_preload = none
}

fn (mut app BrowserApp) commit_preloaded_page(loaded LoadedPage, add_history bool) {
	app.install_loaded_page(loaded, add_history)
	app.update_current_history_entry(loaded)
}

fn (mut app BrowserApp) retain_navigation_resource(resource_url string, resource PreloadedResource) {
	if resource_url !in app.resource_cache && app.resource_cache.len >= max_cached_resources {
		for key, _ in app.resource_cache {
			app.resource_cache.delete(key)
			break
		}
	}
	app.resource_cache[resource_url] = resource
}

fn parse_page_preload_document(loaded LoadedPage, scripting_enabled bool) &dom.Document {
	// Discovery can begin inside another document's callback or frame workspace.
	// Its identity survives that caller while asynchronous resources load.
	persistent := platform.enter_persistent()
	document_url := dom.dom_url_parse(loaded.url.clone(), dom.url_about_blank(), 'UTF-8') or { dom.url_about_blank() }
	mut document := dom.Document.create(document_url)
	// Resource classification resolves computed styles. Use the same font
	// policy as the eventual navigation document, including system-face metrics.
	// Otherwise preflight decodes the deterministic test fonts into permanent
	// font caches even though the native page will never use those faces.
	install_browser_document_font_policies(mut document)
	document.set_display_device_pixel_ratio(html.display_device_pixel_ratio())
	document.enable_native_storage()
	platform.leave_persistent(persistent)
	mut allocations := enter_preload_document_storage(document)
	defer { allocations.finish() }
	document.set_scripting_enabled_by_embedder(scripting_enabled)
	document.set_allow_declarative_shadow_roots(true)
	// The tokenizer publishes its own source; the intermediate decoded response
	// and encoding label do not need the discovery document's full lifetime.
	workspace := platform.begin_thread_scratch('preload decoded input')
	markup, encoding_name := loaded_browser_navigation_input(loaded)
	workspace.leave()
	defer { workspace.finish() }
	if selected_encoding := encoding_name { document.set_encoding(selected_encoding.clone()) }
	// Match noscript parsing without creating a Window, executing import maps
	// or preparing scripts in this resource-discovery document.
	mut parser := html.HTMLParser.create_with_scripting_mode(document, markup,
		if scripting_enabled {
			dom.ParserScriptingMode.inert
		} else {
			dom.ParserScriptingMode.disabled
		})
	parser.resource_discovery_only = scripting_enabled
	parser.run()
	return document
}

// A discovery document has an independent lifetime even when another native
// arena is entered. Ordinary enter_native_storage() preserves that caller.
fn enter_preload_document_storage(document &dom.Document) platform.RetainedArenaScope {
	mut storage := document.native_storage()
	if storage == unsafe { nil } { return platform.RetainedArenaScope{} }
	return storage.enter_nested()
}

fn retire_native_preload_document(document &dom.Document) {
	mut retiring := unsafe { &dom.Document(document) }
	handle := document.layout_engine_handle()
	retiring.destroy_a_document_and_its_descendants()
	retiring.finalize()
	layout.retire_native_document_layout(handle)
	retiring.release_native_storage()
}

fn queue_navigation_preloads(mut pending PendingPagePreload, urls []string,
	types map[string]string, cache map[string]PreloadedResource) {
	pending.remaining += urls.len
	mut jobs := []ResourceFetchJob{cap: urls.len}
	for resource_url in urls {
		// The map also retains the current page's rendering inputs. That does
		// not permit replaying a no-store response into another navigation.
		cached := if resource := cache[resource_url] {
			if browser_response_forbids_storage(resource.response_headers) { []PreloadedResource{} } else { [resource] }
		} else { []PreloadedResource{} }
		jobs << ResourceFetchJob{ url: resource_url.clone(), request_type: types[resource_url] or { 'image' },
			cached: cached }
	}
	spawn_resource_fetch_workers(jobs, pending.loaded.url, true, pending.results)
}

fn fetch_navigation_preload(resource_url string, source_url string, request_type string,
	cached []PreloadedResource, results chan PreloadedResource) {
	platform.retain_thread_allocations()
	fetch_resource_jobs([ResourceFetchJob{ url: resource_url, request_type: request_type, cached: cached }],
		source_url, true, results)
}

fn (mut app BrowserApp) prepare_loaded_page(loaded LoadedPage, add_history bool) {
	history_needed := add_history || if pending := app.pending_page_preload {
		pending.generation == app.navigation_generation && pending.add_history
	} else {
		false
	}
	app.cancel_page_preload()
	if app.ctx == unsafe { nil } {
		app.commit_preloaded_page(loaded, history_needed)
		return
	}
	app.start_page_preload(loaded, history_needed)
}

fn (mut app BrowserApp) start_page_preload(loaded LoadedPage, add_history bool) {
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	scripting_enabled := browser_scripting_enabled(loaded.url, app.script_policy)
		&& (app.page_model == unsafe { nil } || app.page_model.is_scripting_enabled())
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(scripting_enabled)
	defer { heap_scope.finish() }
	app.cancel_page_preload()
	// Discovery owns a detached context. Creating it with the displayed page's
	// context would deactivate that document before its replacement is ready.
	_ = prepare_markup_render_heap(loaded.markup, scripting_enabled)
	if scripting_enabled && !disable_tokenized_navigation_preloads {
		if discovery := tokenized_navigation_preloads(loaded) {
			app.start_tokenized_page_preload(loaded, add_history, discovery)
			return
		}
	}
	mut document := parse_page_preload_document(loaded, scripting_enabled)
	base_url := document.base_url().serialize()
	urls := document_preload_resource_urls(document, base_url)
	types := document_preload_resource_types(document, base_url)
	if urls.len == 0 {
		retire_native_preload_document(document)
		app.commit_preloaded_page(loaded, add_history)
		return
	}
	results := chan PreloadedResource{cap: urls.len}
	mut pending := PendingPagePreload{
		loaded:      loaded
		add_history: add_history
		generation:  app.navigation_generation
		results:     results
	}
	mut initial_urls := []string{}
	svg_images := document_svg_image_preload_urls(document, base_url)
	for resource_url in urls {
		if (types[resource_url] or { 'image' }) == 'image' {
			// Windowed pages use the native image loader after commit. Waiting
			// here lets one slow illustration hold the entire article offscreen.
			if !scripting_enabled && (!app.can_load_images_asynchronously() || resource_url in svg_images) {
				pending.image_urls << resource_url
			}
		} else if (types[resource_url] or { 'image' }) == 'stylesheet' {
			// Scripts are requested by their live parser elements after commit.
			// An async or deferred source must not hold the old document onscreen.
			initial_urls << resource_url
		}
	}
	if pending.image_urls.len > 0 {
		pending.discovery_document = document
	} else {
		retire_native_preload_document(document)
	}
	queue_navigation_preloads(mut pending, initial_urls, types, app.resource_cache)
	app.pending_page_preload = pending
	if pending.remaining == 0 { request_browser_frame() }
}

fn (mut app BrowserApp) poll_page_preload() {
	mut pending := app.pending_page_preload or { return }
	if pending.generation != app.navigation_generation {
		app.cancel_page_preload()
		return
	}
	// Each select builds its channel lists; frames waiting on the network
	// receive nothing, so only select when a result is buffered.
	for pending.remaining > 0 && pending.results.len > 0 {
		select {
			resource := <-pending.results {
				pending.resources[resource.url] = resource
				pending.remaining--
			}
			else {
				break
			}
		}
	}
	if pending.remaining > 0 {
		app.pending_page_preload = pending
		return
	}
	mut navigation_work := app.begin_navigation_work()
	defer { navigation_work.finish() }
	if pending.discovery_document != unsafe { nil } {
		mut document := pending.discovery_document
		mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(document.as_node().is_scripting_enabled())
		defer { heap_scope.finish() }
		base_url := document.base_url().serialize()
		foreground_urls := foreground_preload_urls_in_document_storage(document, base_url,
			pending.resources, pending.image_urls,
			f64(if app.viewport_width > 0 { app.viewport_width } else { initial_width }) / app.page_zoom,
			f64(if app.viewport_height > 0 { app.viewport_height } else { initial_height - app.chrome_height() }) / app.page_zoom)
		retire_native_preload_document(document)
		pending.discovery_document = unsafe { nil }
		pending.image_urls = []string{}
		queue_navigation_preloads(mut pending, foreground_urls, map[string]string{}, app.resource_cache)
		if pending.remaining > 0 {
			app.pending_page_preload = pending
			return
		}
	}
	app.pending_page_preload = none
	// Keep failures too: installation must consume the completed failure rather
	// than retrying the same slow request synchronously on the UI thread. This
	// per-install cache is independent of the bounded reusable resource cache.
	app.navigation_preloaded_resources = pending.resources.clone()
	defer { app.navigation_preloaded_resources = map[string]PreloadedResource{} }
	app.commit_preloaded_page(pending.loaded, pending.add_history)
}

// Styling discovery is part of the detached document's lifetime too. Its
// selectors, resolved styles and invalidation data must retire with that tree,
// rather than accumulating in the shell's base arena before every navigation.
fn foreground_preload_urls_in_document_storage(document &dom.Document, base_url string,
	resources map[string]PreloadedResource, urls []string, width f64, height f64) []string {
	mut allocations := enter_preload_document_storage(document)
	_ = install_external_styles(document, base_url, resources)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{width:width, height:height})
	css.sync_document_style_elements(document)
	foreground, _ := partition_nonrendered_image_preloads(document, base_url, urls)
	allocations.finish()
	// The caller retires the document next; worker arguments belong to the
	// shell, including when the caller itself has a temporary arena entered.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return foreground.map(it.clone())
}

// DOM click activation and the compact script replay share the shell's loader.
// Letting the translated navigable commit separately would replace its active
// Document with an empty one before the shell has fetched the destination.
fn (mut app BrowserApp) install_compact_navigation_handler() {
	mut navigable := app.document.navigable() or { return }
	app_handle := voidptr(&app)
	navigable.navigate_callback_ = fn [app_handle] (_ voidptr, destination dom.URL,
		_ &dom.Document, _ string, _ dom.UserNavigationInvolvement) ! {
		mut app := unsafe { &BrowserApp(app_handle) }
		app.pending_native_navigation = destination.serialize()
		$if macos {
			C.native_wake_browser()
		}
	}
}

fn (mut app BrowserApp) poll_native_navigation() {
	destination := app.pending_native_navigation or { return }
	app.pending_native_navigation = none
	app.navigate(destination, true)
}
