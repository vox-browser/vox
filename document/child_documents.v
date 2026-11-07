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
	initialized        bool
	runtime            &browserjs.Runtime = unsafe { nil }
	scripts            ?&BrowserScriptRequestLoader
	images             ?&BrowserImageRequestLoader
	load_fired         bool
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
	mut storage := document.native_storage()
	if storage != unsafe { nil } {
		storage.add_cleanup(fn [host] () {
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
	navigable.set_navigation_fetch_host(requestserver.native_resource_fetch_host())
	navigable.set_document_created_hook(fn [host] (document &dom.Document) {
		host.prepare_document(document)
	})
	if initial := navigable.active_document() {
		browser_child_document_hosts_[voidptr(initial)] = &host
	}
	host.children << &BrowserChildDocument{ element: element, navigable: navigable }
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
		if !active.get_is_initial_about_blank() { return }
		if mut service := child.service {
			if voidptr(service.document) == voidptr(active) {
				service.initialize(host.engine, mut messages)
				return
			}
			service.close()
		}
		mut service := &BrowserHostedDocument{ document: active }
		child.service = service
		service.initialize(host.engine, mut messages)
		return
	}
}

fn retire_hosted_browser_document(document &dom.Document) {
	mut owner := unsafe { &dom.Document(document) }
	if !owner.has_been_destroyed() { owner.destroy_a_document_and_its_descendants() }
	layout.retire_native_document_layout(owner.layout_engine_handle())
	owner.finalize()
	owner.release_native_storage()
}

fn (host &BrowserChildDocumentHost) prepare_document(document &dom.Document) {
	browser_child_document_hosts_[voidptr(document)] = host
	mut owner := unsafe { &dom.Document(document) }
	install_browser_document_font_policies(mut owner)
	install_browser_document_cookie_client(mut owner)
	owner.set_display_device_pixel_ratio(host.root.display_device_pixel_ratio())
	owner.set_scripting_enabled_by_embedder(host.scripting)
	owner.enable_native_storage()
	layout.enable_native_paint_tree_storage(document)
	layout.enable_native_static_svg_backgrounds(document)
	// Parent scenes contain shallow child paint payloads. Keep their source
	// until the root's last scene reader has released its document storage.
	mut storage := host.root.native_storage()
	if storage != unsafe { nil } {
		storage.add_cleanup(fn [document] () { retire_hosted_browser_document(document) })
	}
}

fn (mut service BrowserHostedDocument) close() {
	if mut loader := service.scripts { loader.cancel() }
	if mut loader := service.images { loader.cancel() }
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

fn (mut service BrowserHostedDocument) start_resources() {
	types := document_preload_resource_types(service.document, service.document.base_url().serialize())
	mut jobs := []ResourceFetchJob{}
	for url in document_preload_resource_urls(service.document, service.document.base_url().serialize()) {
		kind := types[url] or { 'image' }
		if kind == 'image' { continue }
		jobs << ResourceFetchJob{ url: url, request_type: kind }
	}
	service.remaining = jobs.len
	spawn_resource_fetch_workers(jobs, service.document.url.serialize(), true, service.results)
}

fn (mut service BrowserHostedDocument) initialize(engine browserjs.Engine, mut messages []string) {
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
	if service.remaining != 0 || service.initialized { return }
	service.initialized = true
	document := service.document
	base := document.base_url().serialize()
	messages << install_external_styles(document, base, service.resources)
	install_object_image_fetch_hooks(document)
	install_video_poster_fetch_hooks(document)
	mut images := new_browser_image_request_loader(document, service.resources)
	mut scripts := &BrowserScriptRequestLoader{ document: document }
	service.images = images
	service.scripts = scripts
	sources := script_sources(document, base, service.resources, mut messages)
	if document.as_node().is_scripting_enabled() {
		service.runtime = create_browser_script_runtime(engine)
		service.pending_navigation = run_document_script_sources_with_resource_loaders(document, document.url.serialize(), sources,
			service.runtime, browser_fetch_image_request, images.callback(), scripts, mut messages)
	} else {
		install_static_browser_image_fetch_hooks_with_loader(document, map[string]bool{}, images)
	}
	images.finish_initialization(service.runtime != unsafe { nil })
	service.resources = map[string]PreloadedResource{}
}

fn (mut service BrowserHostedDocument) poll(mut messages []string) bool {
	if !service.initialized { return false }
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
	if service.runtime == unsafe { nil } { return changed }
	if mut scripts := service.scripts { scripts.poll(service.runtime, mut messages) }
	mut runtime := service.runtime
	if !service.document.anything_is_delaying_the_load_event() {
		runtime.dispatch_document_readiness_event('load') or { messages << 'Child load: ${err.msg()}' }
	}
	if runtime.take_document_state_dirty() {
		state := runtime.evaluate_host_temporary_text('__ladybirdFinalize()') or { return changed }
		service.pending_navigation = apply_javascript_runtime_state(service.document, state.value, runtime, mut messages)
		state.finish()
		runtime.evaluate_host('__ladybirdClearLogs()') or {}
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
		mut replace := true
		if service := child.service { replace = voidptr(service.document) != voidptr(active) }
		if replace {
			if mut old := child.service { old.close() }
			mut service := &BrowserHostedDocument{ document: active }
			child.service = service
			service.start_resources()
			changed = true
			// Let the parent commit the iframe viewport before child scripts read
			// innerWidth or force their first layout, including hidden zero-size frames.
			continue
		}
		if mut service := child.service {
			was_initialized := service.initialized
			service.initialize(host.engine, mut messages)
			if service.poll(mut messages) || was_initialized != service.initialized {
				changed = true
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
			if service.initialized && !service.load_fired && !active.anything_is_delaying_the_load_event() {
				service.load_fired = true
				src := child.src.clone()
				srcdoc := child.srcdoc
				html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), child.element.document(), fn [child, active, src, srcdoc] () {
					mut owner := unsafe { &BrowserChildDocument(child) }
					defer { owner.release_load_delay() }
					if child.closed || !child.navigable.host_navigable().active_document_is(active) {
						return
					}
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
		if child.navigable.ongoing_navigation().kind == .navigation { return true }
		active := child.navigable.active_document() or { continue }
		service := child.service or { return true }
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
