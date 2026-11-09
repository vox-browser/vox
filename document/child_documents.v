@[has_globals]
module main

import browserjs
import css
import dom
import html
import layout
import platform
import requestserver
import time

@[heap]
struct BrowserChildDocument {
	element   &dom.Element
	navigable &html.NavigableModel
mut:
	src      string
	srcdoc   ?string
	observed bool
	service  ?&BrowserHostedDocument
	prepared_service ?&BrowserHostedDocument
	closed   bool
	// Held on the container document from the start of a navigation until
	// the hosted document has run its scripts and fired its load event.
	load_delay ?dom.DocumentLoadEventDelayer
}

fn (mut child BrowserChildDocument) hold_load_delay() {
	if child.load_delay != none { return }
	mut owner := unsafe { &dom.Document(child.element.document()) }
	child.load_delay = dom.DocumentLoadEventDelayer.new(mut owner)
}

fn (mut child BrowserChildDocument) release_load_delay() {
	mut delay := child.load_delay or { return }
	child.load_delay = none
	delay.finish()
	child.element.document().request_frame()
}

@[heap]
struct BrowserHostedDocument {
	document &dom.Document
	results  chan PreloadedResource = chan PreloadedResource{cap: max_concurrent_resource_fetches}
mut:
	resources          map[string]PreloadedResource
	remaining          int
	resources_started  bool
	initialized        bool
	closed             bool
	runtime            &browserjs.Runtime = unsafe { nil }
	parser_host        ?&BrowserParserScriptHost
	media_owner        &BrowserApp = unsafe { nil }
	scripts            ?&BrowserScriptRequestLoader
	images             ?&BrowserImageRequestLoader
	resource_delay     ?dom.DocumentLoadEventDelayer
	adblock_tokens     BrowserAdblockTokenCache
	load_fired         bool
	load_parser_generation u64
	pending_navigation ?string
}

@[heap]
struct BrowserChildDocumentHost {
	root      &dom.Document
	engine    browserjs.Engine
	scripting bool
mut:
	children []&BrowserChildDocument
	scanned  map[dom.UniqueNodeID]BrowserChildDocumentRevision
	closed   bool
	// Monotonic time at which the children last started needing polls.
	pending_since i64
}

struct BrowserChildDocumentRevision {
	tree       u64
	attributes u64
}

// Eager contentWindow reads and the embedding share one owner, including frames
// removed before the next host poll and descendants created by child scripts.
__global browser_child_document_hosts_ = map[voidptr]&BrowserChildDocumentHost{}

fn browser_child_document_host(document &dom.Document, engine browserjs.Engine) &BrowserChildDocumentHost {
	if host := browser_child_document_hosts_[voidptr(document)] { return host }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host := &BrowserChildDocumentHost{
		root:      document
		engine:    engine
		scripting: document.as_node().is_scripting_enabled()
	}
	browser_child_document_hosts_[voidptr(document)] = host
	if document.native_storage() != unsafe { nil } {
		mut document_owner := unsafe { &dom.Document(document) }
		document_owner.add_native_storage_cleanup(fn [host] () {
			mut owner := unsafe { &BrowserChildDocumentHost(host) }
			owner.close()
		})
	}
	return host
}

fn (mut host BrowserChildDocumentHost) ensure_child(element &dom.Element) !&html.NavigableModel {
	if host.closed { return error('InvalidStateError: child document host is closed') }
	for child in host.children {
		if !child.closed && voidptr(child.element) == voidptr(element) { return child.navigable }
	}
	mut navigable := html.create_child_navigable_for_element(element)!
	child := &BrowserChildDocument{ element: element, navigable: navigable }
	host.children << child
	navigable.set_navigation_fetch_host(requestserver.native_resource_fetch_host())
	navigable.set_document_created_hook(fn [host, child] (document &dom.Document) {
		host.prepare_document(child, document)
	})
	if initial := navigable.active_document() {
		browser_child_document_hosts_[voidptr(initial)] = &host
	}
	return navigable
}

// A script can read an iframe's contentWindow before the next host poll. The
// initial about:blank document has no resources to fetch, so its realm is
// created at once and contentDocument.open()/write() reach a live document.
fn (mut host BrowserChildDocumentHost) ensure_initial_realm(element &dom.Element, mut messages []string) {
	for index in 0 .. host.children.len {
		mut child := host.children[index]
		if child.closed || voidptr(child.element) != voidptr(element) { continue }
		active := child.navigable.active_document() or { return }
		if mut service := child.service {
			if voidptr(service.document) == voidptr(active) {
				service.ensure_initial_realm(mut messages)
				return
			}
			service.close()
		}
		if !active.get_is_initial_about_blank() { return }
		mut service := new_browser_hosted_document(active, host.engine)
		child.service = service
		service.ensure_initial_realm(mut messages)
		return
	}
}

fn retire_hosted_browser_document(document &dom.Document) {
	mut owner := unsafe { &dom.Document(document) }
	if owner.native_storage() == unsafe { nil } { return }
	layout_handle := owner.layout_engine_handle()
	if !owner.has_been_destroyed() { owner.destroy_a_document_and_its_descendants() }
	layout.retire_native_document_layout(layout_handle)
	owner.layout_engine_handle_ = unsafe { nil }
	owner.cached_display_list_ = unsafe { nil }
	owner.finalize()
	owner.release_native_storage()
}

fn (host &BrowserChildDocumentHost) prepare_document(child &BrowserChildDocument, document &dom.Document) {
	browser_child_document_hosts_[voidptr(document)] = host
	mut owner := unsafe { &dom.Document(document) }
	install_browser_document_font_policies(mut owner)
	install_browser_document_cookie_client(mut owner)
	owner.set_display_device_pixel_ratio(host.root.display_device_pixel_ratio())
	owner.set_scripting_enabled_by_embedder(host.scripting)
	owner.enable_native_storage()
	layout.enable_native_paint_tree_storage(document)
	layout.enable_native_static_svg_backgrounds(document)
	// The creation hook runs before response parsing, including the streamed
	// parser. Publish the service now so a parser-blocking fetch can be polled
	// before the first script has created a JavaScript runtime.
	mut frame := unsafe { &BrowserChildDocument(child) }
	if mut previous := frame.prepared_service { previous.close() }
	frame.prepared_service = new_browser_hosted_document(document, host.engine)
	// Parser-time scripts can read innerWidth immediately. Commit the parent's
	// current layout and copy the frame's content box in CSS pixels, including
	// zero-sized/hidden frames, before the navigation activates this document.
	parent := child.element.document()
	viewport := parent.viewport_rect()
	_ = layout.run_document_layout(parent, viewport.width, viewport.height)
	if box := child.element.as_node().layout_node() {
		scale := parent.layout_coordinate_scale()
		owner.set_viewport_rect(dom.Rect{0, 0, box.content_width_ / scale, box.content_height_ / scale})
	} else {
		owner.set_viewport_rect(dom.Rect{})
	}
	// Close child publishers when the root document owner retires. Parent
	// caches and scenes hold their own child-scene leases, so copied payloads
	// remain readable until their final consumer releases them. Waiting for
	// the root arena's final cleanup here would cycle with adopted child nodes.
	if host.root.native_storage() != unsafe { nil } {
		mut root := unsafe { &dom.Document(host.root) }
		persistent := platform.enter_persistent()
		root.add_native_storage_cleanup(fn [document] () { retire_hosted_browser_document(document) })
		platform.leave_persistent(persistent)
	}
}

fn new_browser_hosted_document(document &dom.Document, engine browserjs.Engine) &BrowserHostedDocument {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut service := &BrowserHostedDocument{ document: document }
	mut images := new_browser_image_request_loader(document, map[string]PreloadedResource{})
	mut scripts := new_browser_script_request_loader(document, map[string]PreloadedResource{})
	service.images = images
	service.scripts = scripts
	mut media_loader := ?browserjs.MediaElementCreatedHook(none)
	$if macos {
		service.media_owner = &BrowserApp{document:document}
		service.media_owner.install_document_media_playback()
		media_loader = fn [service] (element &dom.Element) {
			if service.media_owner != unsafe { nil } { service.media_owner.install_media_playback(element) }
		}
	}
	service.parser_host = install_browser_parser_script_host(document, engine, images, scripts,
		map[string]PreloadedResource{}, media_loader, fn [service] (runtime &browserjs.Runtime) {
			mut owner := unsafe { &BrowserHostedDocument(service) }
			owner.runtime = runtime
		})
	install_object_image_fetch_hooks(document)
	install_video_poster_fetch_hooks(document)
	// Initial styles and static images are installed once parsing exposes the
	// complete tree. Keep that work inside the parser's load-event boundary.
	if !document.get_is_initial_about_blank() {
		mut owner := unsafe { &dom.Document(document) }
		service.resource_delay = dom.DocumentLoadEventDelayer.new(mut owner)
	}
	return service
}

fn (mut service BrowserHostedDocument) finish_resource_delay() {
	mut delay := service.resource_delay or { return }
	service.resource_delay = none
	delay.finish()
}

fn (mut service BrowserHostedDocument) ensure_initial_realm(mut messages []string) {
	if mut host := service.parser_host { host.initialize() }
	service.initialize(mut messages)
	if mut host := service.parser_host {
		if destination := host.flush(mut messages) { service.pending_navigation = destination }
	}
}

fn (mut service BrowserHostedDocument) close() {
	if service.closed { return }
	service.closed = true
	if service.media_owner != unsafe { nil } {
		service.media_owner.close_media_playback()
		service.media_owner = unsafe { nil }
	}
	if mut host := service.parser_host { host.closed = true }
	if mut loader := service.scripts { loader.cancel() }
	if mut loader := service.images { loader.cancel() }
	service.finish_resource_delay()
	service.adblock_tokens.release()
	if service.runtime != unsafe { nil } {
		service.runtime.close()
		service.runtime = unsafe { nil }
	}
}

fn (mut child BrowserChildDocument) close() {
	if child.closed { return }
	child.closed = true
	child.release_load_delay()
	mut navigable := unsafe { &html.NavigableModel(child.navigable) }
	context := navigable.active_browsing_context()
	if mut document := navigable.active_document() {
		if !document.has_been_destroyed() {
			document.unload_a_document_and_its_descendants(none)
			if !document.has_been_destroyed() { document.destroy_a_document_and_its_descendants() }
		}
	}
	if mut service := child.service { service.close() }
	if mut service := child.prepared_service { service.close() }
	child.prepared_service = none
	navigable.set_has_been_destroyed()
	navigable.remove_from_all_navigables()
	navigable.host_navigable().remove_from_all_navigables()
	if mut value := context { value.remove() }
}

fn (mut host BrowserChildDocumentHost) close() {
	if host.closed { return }
	host.closed = true
	for index := host.children.len - 1; index >= 0; index-- {
		host.children[index].close()
	}
	host.children = []&BrowserChildDocument{}
	mut retired := []voidptr{}
	for document, owner in browser_child_document_hosts_ {
		if voidptr(owner) == voidptr(&host) { retired << document }
	}
	for document in retired { browser_child_document_hosts_.delete(document) }
}

fn (mut host BrowserChildDocumentHost) discover(document &dom.Document, mut messages []string) {
	version := BrowserChildDocumentRevision{document.dom_tree_version(), document.attribute_version()}
	key := document.unique_id()
	if previous := host.scanned[key] {
		if previous == version { return }
	}
	host.scanned[key] = version
	for element in css.query_selector_all(document.as_node(), 'iframe') {
		if !element.is_html_element() || !element.as_node().is_connected() { continue }
		host.ensure_child(element) or {
			messages << 'Child browsing context: ${err.msg()}'
			continue
		}
	}
}

fn (mut child BrowserChildDocument) process_attributes(mut messages []string) {
	src := child.element.get_attribute_value('src')
	srcdoc := child.element.get_attribute('srcdoc')
	if child.observed && src == child.src && srcdoc == child.srcdoc { return }
	if child.observed && srcdoc != none && srcdoc == child.srcdoc {
		child.src = src.clone()
		return
	}
	initial := !child.observed
	child.observed = true
	child.src = src.clone()
	child.srcdoc = if value := srcdoc { ?string(value.clone()) } else { none }
	owner := child.element.document()
	url := if srcdoc != none {
		dom.URL{ value: 'about:srcdoc' }
	} else if src == '' {
		dom.url_about_blank()
	} else {
		dom.dom_url_parse(src, owner.base_url(), 'UTF-8') or { dom.url_about_blank() }
	}
	if initial && srcdoc == none && (src == '' || url.serialize() == 'about:blank') { return }
	mut ancestor := owner.navigable()
	for ancestor != none {
		current := ancestor or { break }
		if active_url := current.active_document_url() {
			if active_url.serialize().all_before('#') == url.serialize().all_before('#') { return }
		}
		ancestor = current.parent()
	}
	mut navigable := unsafe { &html.NavigableModel(child.navigable) }
	mut iframe := html.html_iframe_element_model_for_dom_element(unsafe { &dom.HTMLIFrameElement(child.element) })
	iframe.set_sandbox(child.element.get_attribute('sandbox'))
	resource := if value := srcdoc {
		html.DocumentResource(value)
	} else {
		html.DocumentResource(html.EmptyDocumentResource{})
	}
	navigable.navigate(html.NavigableNavigateParams{
		url:               url
		source_document:   owner
		document_resource: resource
		initial_insertion: if initial { .yes } else { .no }
		referrer_policy:   html.referrer_policy_from_string(child.element.get_attribute_value('referrerpolicy')) or { html.ReferrerPolicy.empty_string }
	}) or {
		messages << 'Child navigation: ${err.msg()}'
		return
	}
	child.hold_load_delay()
}

// Start the navigations of a document's iframes before its load event is
// considered. Each one then delays its container's load event until the
// hosted document has run its scripts and fired its own load event.
fn start_browser_child_navigations(document &dom.Document, engine browserjs.Engine, mut messages []string) {
	mut host := browser_child_document_host(document, engine)
	if host.closed { return }
	host.discover(document, mut messages)
	for index in 0 .. host.children.len {
		mut child := host.children[index]
		if child.closed || child.observed || voidptr(child.element.document()) != voidptr(document) {
			continue
		}
		if !child.element.as_node().is_connected() { continue }
		child.process_attributes(mut messages)
	}
}

// Parser-time installation may already have completed a link, even when its
// response cannot be reused from a cache. Decide which owners still need bytes
// before deduplicating their transport URLs.
fn browser_hosted_stylesheet_resource_jobs(document &dom.Document) []ResourceFetchJob {
	root := document.as_node()
	base_url := document.base_url().serialize()
	preferred_set_name := preferred_style_sheet_set_name(root)
	mut jobs := []ResourceFetchJob{}
	mut seen := map[string]bool{}
	for link in css.query_selector_all(root, 'link[rel][href]') {
		if !link.is_html_element()
			|| (!link_stylesheet_applies(link, preferred_set_name) && !link_is_style_preload(link)) {
			continue
		}
		if unsafe { &dom.HTMLLinkElement(link) }.linked_style_sheet_ != unsafe { nil } { continue }
		url := resolve_document_reference(link.get_attribute_value('href'), base_url)
		if (!url.starts_with('http://') && !url.starts_with('https://')) || url in seen { continue }
		seen[url] = true
		jobs << ResourceFetchJob{ url: url, request_type: 'stylesheet' }
	}
	return jobs
}

fn (mut service BrowserHostedDocument) start_resources() {
	if service.resources_started || service.closed { return }
	// A blocking script may have paused the parser before later stylesheet
	// elements exist. Its loader progresses independently in poll().
	if service.document.ready_state() == 'loading' || service.document.has_deferred_parser_start() { return }
	service.resources_started = true
	// Script requests already belong to the live parser. Completed stylesheets
	// likewise need no additional request in this installation barrier.
	jobs := browser_hosted_stylesheet_resource_jobs(service.document)
	service.remaining = jobs.len
	spawn_resource_fetch_workers(jobs, service.document.url.serialize(), true, service.results)
}

fn (mut service BrowserHostedDocument) initialize(mut messages []string) {
	if service.closed { return }
	service.start_resources()
	for service.results.len > 0 {
		select {
			resource := <-service.results {
				service.remaining--
				service.resources[resource.url] = resource
			}
			else {
				break
			}
		}
	}
	if !service.resources_started || service.remaining != 0 || service.initialized { return }
	service.initialized = true
	document := service.document
	base := document.base_url().serialize()
	messages << install_parser_external_styles(document, base, service.resources)
	// Each frame is a separate filtering document. The parent's user sheet
	// cannot hide adverts inside a same-origin or cross-origin child.
	install_browser_adblock_styles_with_tokens(document, '', mut service.adblock_tokens) or {
		messages << 'Child adblock styles: ${err.msg()}'
	}
	mut images := service.images or { return }
	if service.runtime == unsafe { nil } {
		install_static_browser_image_fetch_hooks_with_loader(document, map[string]bool{}, images)
	}
	images.finish_initialization(service.runtime != unsafe { nil })
	refresh_browser_adblock_with_tokens(document, service.runtime, mut messages,
		mut service.adblock_tokens)
	service.resources = map[string]PreloadedResource{}
	service.finish_resource_delay()
}

fn (mut service BrowserHostedDocument) poll(mut messages []string) bool {
	if service.closed { return false }
	if service.media_owner != unsafe { nil } { service.media_owner.poll_media_playback() }
	mut changed := false
	if mut loader := service.images {
		for loader.results.len > 0 {
			select {
				resource := <-loader.results {
					loader.active_fetches--
					key := resource.source_url + '\n' + resource.url
					callbacks := loader.pending[key] or { continue }
					loader.pending.delete(key)
					mut decoded := ?html.DecodedImageData(none)
					if resource.error == '' {
						if address := dom.dom_url_parse(resource.url, service.document.base_url(), 'UTF-8') {
							if value := browser_decoded_image_data(address, resource.body.bytes()) {
								decoded = value
							}
						}
					}
					for callback in callbacks { finish_browser_image_request(callback, decoded) }
					changed = true
				}
				else {
					break
				}
			}
		}
		loader.start_queued_fetches()
	}
	if mut scripts := service.scripts { scripts.poll(service.runtime, mut messages) }
	if mut host := service.parser_host {
		if destination := host.flush(mut messages) { service.pending_navigation = destination }
	}
	if service.runtime == unsafe { nil } {
		if service.adblock_tokens.tree_version != service.document.dom_tree_version()
			|| service.adblock_tokens.attribute_version != service.document.attribute_version() {
			refresh_browser_adblock_with_tokens(service.document, service.runtime, mut messages,
				mut service.adblock_tokens)
			changed = true
		}
		return changed
	}
	mut runtime := service.runtime
	if runtime.take_document_state_dirty() {
		refresh_browser_adblock_with_tokens(service.document, runtime, mut messages,
			mut service.adblock_tokens)
		changed = true
	}
	return changed
}

fn (mut host BrowserChildDocumentHost) poll(mut messages []string) bool {
	if host.closed { return false }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut changed := false
	host.discover(host.root, mut messages)
	// Snapshot the length: discovery in a child can append its descendants.
	for index in 0 .. host.children.len {
		mut child := host.children[index]
		if child.closed { continue }
		if !child.element.as_node().is_connected() || !child.element.document().is_fully_active() {
			child.close()
			changed = true
			continue
		}
		child.process_attributes(mut messages)
		active := child.navigable.active_document() or { continue }
		if child.navigable.ongoing_navigation().kind == .navigation && active.get_is_initial_about_blank() {
			continue
		}
		if mut prepared := child.prepared_service {
			if voidptr(prepared.document) == voidptr(active) {
				// Preparation happens before history activation. Keep the outgoing
				// realm alive through navigation and retire it only after commit.
				if mut previous := child.service { previous.close() }
				child.service = prepared
				child.prepared_service = none
				changed = true
			} else if child.navigable.ongoing_navigation().kind != .navigation {
				prepared.close()
				child.prepared_service = none
			}
		}
		mut replace := true
		if service := child.service { replace = voidptr(service.document) != voidptr(active) }
		if replace {
			if mut old := child.service { old.close() }
			mut service := new_browser_hosted_document(active, host.engine)
			child.service = service
			changed = true
		}
		if mut service := child.service {
			was_initialized := service.initialized
			service.initialize(mut messages)
			if service.poll(mut messages) || was_initialized != service.initialized {
				changed = true
			}
			parser_generation := if parser := service.parser_host { parser.parser_generation } else { u64(0) }
			if parser_generation != service.load_parser_generation {
				// document.open() replaces the parser without replacing the realm
				// or document. Its new stream owns a fresh container completion.
				service.load_fired = false
				child.hold_load_delay()
			}
			if destination := service.pending_navigation {
				service.pending_navigation = none
				if destination != '' {
					mut navigable := unsafe { &html.NavigableModel(child.navigable) }
					if target := dom.dom_url_parse(destination, active.base_url(), 'UTF-8') {
						navigable.navigate(html.NavigableNavigateParams{ url: target, source_document: active }) or {
							messages << 'Child script navigation: ${err.msg()}'
						}
					}
				}
			}
			if service.initialized && !service.load_fired && active.ready_state() == 'complete'
				&& !active.anything_is_delaying_the_load_event() {
				service.load_fired = true
				service.load_parser_generation = parser_generation
				src := child.src.clone()
				srcdoc := child.srcdoc
				html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), child.element.document(), fn [child, service, active, src, srcdoc, parser_generation] () {
					mut owner := unsafe { &BrowserChildDocument(child) }
					if child.closed || service.closed || !child.navigable.host_navigable().active_document_is(active) {
						return
					}
					if parser := service.parser_host {
						// A queued completion must not fire for a replacement stream
						// or release the parent delay that stream now owns.
						if parser.parser_generation != parser_generation { return }
					}
					defer { owner.release_load_delay() }
					// The event belongs to the document these attributes loaded. Once
					// script replaces them, a browser would already have fired it, so
					// it must not reach handlers installed for the next navigation.
					if child.element.get_attribute_value('src') != src
						|| !optional_strings_equal(child.element.get_attribute('srcdoc'), srcdoc) {
						return
					}
					// The initial about:blank document fires load only for a frame that
					// still has no source; a navigation already replaced it otherwise.
					if active.get_is_initial_about_blank() && !browser_child_frame_stays_blank(child.element) {
						return
					}
					child.element.as_node().dispatch_event(dom.Event.create('load', dom.EventInit{}))
				})
			}
			host.discover(active, mut messages)
		}
	}
	return changed
}

fn browser_child_frame_stays_blank(element &dom.Element) bool {
	if element.get_attribute('srcdoc') != none {
		return false
	}
	src := element.get_attribute_value('src')
	return src == '' || src == 'about:blank'
}

fn optional_strings_equal(a ?string, b ?string) bool {
	if left := a {
		right := b or { return false }
		return left == right
	}
	return b == none
}

// Navigation, initialization and the load event of a child advance only in
// host polls. A hidden frame paints nothing, so its progress requests no frame.
fn (host &BrowserChildDocumentHost) has_pending_work() bool {
	for child in host.children {
		if child.closed { continue }
		if child.prepared_service != none { return true }
		if child.navigable.ongoing_navigation().kind == .navigation { return true }
		active := child.navigable.active_document() or { continue }
		service := child.service or { return true }
		if parser := service.parser_host {
			if parser.parser_generation != service.load_parser_generation { return true }
		}
		if voidptr(service.document) != voidptr(active) || !service.initialized || !service.load_fired {
			return true
		}
	}
	return false
}

fn (mut app BrowserApp) poll_browser_child_documents() {
	if app.document == unsafe { nil } || app.page_model == unsafe { nil } { return }
	if app.child_document_host == none {
		app.child_document_host = browser_child_document_host(app.document, app.js_engine)
	}
	mut host := app.child_document_host or { return }
	if host.poll(mut app.js_messages) {
		// Child service work changes the iframe's pixels, not its parent's
		// geometry. A real navigation already invalidates the container through
		// Navigable.set_active_document(); retain that source invalidation.
		app.document.set_needs_repaint()
		app.synchronize_javascript_task_paint(false)
		app.request_document_frame()
	}
	if host.has_pending_work() {
		// Poll at frame rate while the work is fresh, then back off so a child
		// that never finishes loading does not keep the browser awake.
		now := i64(time.sys_mono_now())
		if host.pending_since == 0 { host.pending_since = now }
		$if macos {
			C.native_wake_browser_after(if now - host.pending_since < 2 * time.second { 16 } else { 200 })
		}
	} else {
		host.pending_since = 0
	}
}
