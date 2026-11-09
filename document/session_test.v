module main

import browsernet
import browserjs
import dom
import html
import layout
import page
import painting
import time

fn document_session_test_app() &BrowserApp {
	return &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		script_policy:   .disabled
		viewport_width:  320
		viewport_height: 200
	}
}

fn document_session_test_page(name string) LoadedPage {
	return LoadedPage{
		url:          'https://document-session.example/${name}'
		markup:       '<!doctype html><title>${name}</title><style>body{margin:0}p{height:600px}</style><p>${name}</p>'
		content_type: 'text/html'
		status:       'Loaded ${name}'
	}
}

fn document_session_test_finish_loading(document &dom.Document) {
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		if document.document_page_showing() { return }
		event_loop.process()
	}
	assert document.document_page_showing()
}

@[heap]
struct DocumentSessionTestProbe {
mut:
	closed                 int
	document_cleanup       int
	storage_cleanup        int
	pageshow               int
	pageshow_owner_matches bool
}

fn test_back_forward_navigation_transfers_the_document_session_identity() {
	mut app := document_session_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(document_session_test_page('first'), true)
	document_session_test_finish_loading(app.document)
	first := app.DocumentSessionRef
	first_document := app.document
	app.js_messages << 'session-owned message'
	app.script_stylesheet_requests['https://document-session.example/owned.css'] = true
	app.script_stylesheet_responses['https://document-session.example/owned.css'] = PreloadedResource{
		url:  'https://document-session.example/owned.css'
		body: 'p{color:green}'
	}
	app.script_image_requests['https://document-session.example/owned.png'] = true
	app.nonrendered_image_preloads['https://document-session.example/deferred.png'] = true
	app.set_scroll_y(60, app.viewport_height + app.chrome_height())

	app.install_loaded_page(document_session_test_page('second'), true)
	document_session_test_finish_loading(app.document)
	second := app.DocumentSessionRef
	assert voidptr(first) != voidptr(second)
	assert first.state == .suspended
	assert second.state == .active
	assert app.back_forward_cache.pages.len == 1
	assert voidptr(app.back_forward_cache.pages[0].session) == voidptr(first)
	assert app.script_stylesheet_requests.len == 0
	assert app.script_stylesheet_responses.len == 0
	assert app.script_image_requests.len == 0
	assert app.nonrendered_image_preloads.len == 0
	assert 'session-owned message' !in app.js_messages

	app.history_go(-1)
	assert voidptr(app.DocumentSessionRef) == voidptr(first)
	assert voidptr(app.document) == voidptr(first_document)
	assert first.state == .active
	assert second.state == .suspended
	assert app.scroll_y == 60
	assert 'session-owned message' in app.js_messages
	assert 'https://document-session.example/owned.css' in app.script_stylesheet_requests
	assert app.script_stylesheet_responses['https://document-session.example/owned.css'].body == 'p{color:green}'
	assert 'https://document-session.example/owned.png' in app.script_image_requests
	assert 'https://document-session.example/deferred.png' in app.nonrendered_image_preloads

	app.history_go(1)
	assert voidptr(app.DocumentSessionRef) == voidptr(second)
	assert app.script_stylesheet_responses.len == 0
	assert app.js_messages.len == 0
}

fn test_pending_background_requests_retire_with_their_session() {
	mut app := document_session_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(document_session_test_page('resource-owner'), true)
	document_session_test_finish_loading(app.document)
	first := app.DocumentSessionRef
	address := 'https://document-session.example/late-resource.bin'
	app.background_resource_pending[address] = true
	app.background_resource_jobs++
	results := app.background_resource_results
	scope := app.resource_request_scope()
	scope.retain()
	defer { scope.release() }
	assert app.back_forward_cache_blocker() == 'resource requests'
	app.install_loaded_page(document_session_test_page('replacement'), true)
	document_session_test_finish_loading(app.document)
	assert first.state == .retired
	assert scope.is_cancelled()
	assert !browsernet.publish_result(PreloadedResource{url: address}, results, scope)
	assert app.background_resource_results.len == 0
	assert address !in app.background_resource_pending
	app.poll_background_resources()
	assert address !in app.resource_cache
	assert app.background_resource_jobs == 0
}

fn document_session_test_background_worker(results chan PreloadedResource, started chan bool,
	finished chan bool, index int) {
	started <- true
	results <- PreloadedResource{ url: 'https://document-session.example/retired-${index}' }
	finished <- true
}

fn test_retiring_a_full_response_queue_releases_every_outstanding_worker() {
	mut session := new_document_session()
	// More producers than buffer slots expose a missing retirement drain without
	// any network dependency. Workers retain the original destination channel.
	jobs := 9
	session.background_resource_results = chan PreloadedResource{cap: 2}
	session.background_resource_jobs = jobs
	results := session.background_resource_results
	started := chan bool{cap: jobs}
	finished := chan bool{cap: jobs}
	for index in 0 .. jobs {
		spawn document_session_test_background_worker(results, started, finished, index)
	}
	for _ in 0 .. jobs {
		select {
			_ := <-started {
			}
			5 * time.second {
				assert false, 'background fixture did not start'
			}
		}
	}
	session.retire()
	assert session.background_resource_jobs == 0
	for _ in 0 .. jobs {
		select {
			_ := <-finished {
			}
			5 * time.second {
				assert false, 'retired background response worker remained blocked'
			}
		}
	}
}

fn test_pageshow_observes_the_resumed_session_as_the_application_owner() {
	mut app := document_session_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(document_session_test_page('pageshow-owner'), true)
	document_session_test_finish_loading(app.document)
	first := app.DocumentSessionRef
	window := app.document.get_window() or { panic('missing Window') }
	probe := &DocumentSessionTestProbe{}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [app, first, probe] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observed := unsafe { &DocumentSessionTestProbe(probe) }
			observed.pageshow++
			observed.pageshow_owner_matches = voidptr(app.DocumentSessionRef) == voidptr(first)
				&& first.state == .active && voidptr(app.document) == voidptr(first.document)
			return dom.js_undefined()
		}
	})
	unsafe { &dom.EventTarget(window) }.add_event_listener_without_options('pageshow', listener)
	app.install_loaded_page(document_session_test_page('pageshow-away'), true)
	document_session_test_finish_loading(app.document)
	app.history_go(-1)
	assert probe.pageshow == 1
	assert probe.pageshow_owner_matches
}

fn test_tab_retirement_closes_the_whole_session_once_even_when_close_reenters() {
	mut app := document_session_test_app()
	app.install_loaded_page(document_session_test_page('retire'), true)
	document_session_test_finish_loading(app.document)
	session := app.DocumentSessionRef
	document := app.document
	images := app.image_request_loader or { panic('missing image loader') }
	scripts := app.script_request_loader or { panic('missing script loader') }
	host := browser_child_document_host(document, .javascriptcore)
	app.child_document_host = host
	mut runtime := browserjs.Runtime.create()
	app.js_runtime = runtime
	probe := &DocumentSessionTestProbe{}
	runtime.add_close_handler(fn [session, probe] () {
		mut observed := unsafe { &DocumentSessionTestProbe(probe) }
		observed.closed++
		mut retiring := unsafe { &DocumentSession(session) }
		retiring.retire()
	})
	video := document.create_element('video') or { panic(err) }
	media := html.html_media_element_for_dom_element(video) or { panic('missing media owner') }
	player := &BrowserMediaPlayback{
		media:           media
		element:         video
		metadata_loaded: true
		frame:           painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{
			width:  1
			height: 1
			pitch:  4
			data:   [u8(1), 2, 3, 255]
		})
	}
	app.media_players << player
	// Keep the original payload readable while inspecting cancelled owners.
	lease := layout.retain_display_list_scene(app.paint_display_list)
	defer { layout.release_display_list_scene(lease) }
	assert app.paint_commands.len > 0
	command_copy := app.paint_commands[0]
	app.draw_command_copies << &command_copy
	app.rounded_rect_underlay = app.paint_commands[0]
	app.rounded_rect_underlay_source = app.paint_commands[0]
	app.background_image_border = app.paint_commands[0]
	app.pointer_clicks.document = voidptr(document)
	app.frame_aligned_wheel = DeferredPageInput{ document: voidptr(document) }
	app.history_scroll_restoration = HistoryScrollRestoration{ document: voidptr(document), replaced: voidptr(document) }
	app.dispose_browser_tab()
	app.dispose_browser_tab()
	app.request_background_resource('data:,retired-session')
	app.poll_background_resources()
	assert session.state == .retired
	assert session.background_resource_jobs == 0
	assert probe.closed == 1
	assert images.cancelled && scripts.cancelled && host.closed
	has_frame := player.frame != none
	has_image_loader := session.image_request_loader != none
	has_script_loader := session.script_request_loader != none
	has_child_host := session.child_document_host != none
	assert !player.metadata_loaded && !has_frame
	assert voidptr(session.document) == unsafe { nil }
	assert voidptr(session.js_runtime) == unsafe { nil }
	assert !has_image_loader && !has_script_loader && !has_child_host
	assert session.media_players.len == 0
	assert session.paint_tree_storage == unsafe { nil }
	assert session.paint_scene == unsafe { nil }
	assert voidptr(session.paint_display_list) == unsafe { nil }
	assert session.paint_commands.len == 0
	assert session.root_box.children.len == 0
	assert session.draw_command_copies.len == 0
	has_underlay := session.rounded_rect_underlay != none
	has_underlay_source := session.rounded_rect_underlay_source != none
	has_border := session.background_image_border != none
	assert !has_underlay && !has_underlay_source && !has_border
	assert app.pointer_clicks.document == unsafe { nil }
	has_wheel := app.frame_aligned_wheel != none
	has_restoration := app.history_scroll_restoration != none
	assert !has_wheel && !has_restoration
	assert document.has_been_destroyed()
}

fn test_cache_eviction_uses_the_same_session_retirement_boundary() {
	mut app := document_session_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(document_session_test_page('evict'), true)
	document_session_test_finish_loading(app.document)
	first := app.DocumentSessionRef
	images := app.image_request_loader or { panic('missing image loader') }
	scripts := app.script_request_loader or { panic('missing script loader') }
	mut runtime := browserjs.Runtime.create()
	app.js_runtime = runtime
	probe := &DocumentSessionTestProbe{}
	runtime.add_close_handler(fn [probe] () {
		mut observed := unsafe { &DocumentSessionTestProbe(probe) }
		observed.closed++
	})
	lease := layout.retain_display_list_scene(app.paint_display_list)
	defer { layout.release_display_list_scene(lease) }
	app.install_loaded_page(document_session_test_page('eviction-successor'), true)
	second := app.DocumentSessionRef
	assert first.state == .suspended
	assert probe.closed == 0
	assert !images.cancelled && !scripts.cancelled
	app.clear_back_forward_cache()
	app.clear_back_forward_cache()
	assert first.state == .retired
	assert voidptr(first.document) == unsafe { nil }
	assert voidptr(first.js_runtime) == unsafe { nil }
	assert probe.closed == 1
	assert images.cancelled && scripts.cancelled
	assert voidptr(app.DocumentSessionRef) == voidptr(second)
	assert second.state == .active
}

fn test_session_retirement_releases_native_storage_after_the_last_frame_reader() {
	$if !prealloc {
		return
	}
	mut app := document_session_test_app()
	app.install_loaded_page(document_session_test_page('retained-frame'), true)
	document_session_test_finish_loading(app.document)
	session := app.DocumentSessionRef
	mut document := app.document
	mut storage := document.native_storage()
	assert voidptr(storage) != unsafe { nil }
	probe := &DocumentSessionTestProbe{}
	document.add_native_storage_cleanup(fn [probe] () {
		mut observed := unsafe { &DocumentSessionTestProbe(probe) }
		observed.document_cleanup++
	})
	storage.add_cleanup(fn [probe] () {
		mut observed := unsafe { &DocumentSessionTestProbe(probe) }
		observed.storage_cleanup++
	})
	lease := layout.retain_display_list_scene(app.paint_display_list)
	commands := app.paint_commands
	assert lease != unsafe { nil }
	app.dispose_browser_tab()
	assert session.state == .retired
	assert probe.document_cleanup == 1
	assert probe.storage_cleanup == 0
	assert commands.any(it.text == 'retained-frame')
	layout.release_display_list_scene(lease)
	assert probe.storage_cleanup == 1
	app.dispose_browser_tab()
	assert probe.document_cleanup == 1 && probe.storage_cleanup == 1
}

fn test_eviction_finishes_retirement_when_the_cached_document_was_destroyed() {
	mut app := document_session_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(document_session_test_page('already-destroyed'), true)
	document_session_test_finish_loading(app.document)
	first := app.DocumentSessionRef
	mut document := app.document
	probe := &DocumentSessionTestProbe{}
	document.add_native_storage_cleanup(fn [probe] () {
		mut observed := unsafe { &DocumentSessionTestProbe(probe) }
		observed.document_cleanup++
	})
	app.install_loaded_page(document_session_test_page('live-successor'), true)
	document.destroy_a_document_and_its_descendants()
	assert document.has_been_destroyed()
	assert first.state == .suspended
	app.clear_back_forward_cache()
	assert first.state == .retired
	assert voidptr(first.document) == unsafe { nil }
	assert voidptr(document.native_storage()) == unsafe { nil }
	assert probe.document_cleanup == 1
	assert app.document.url_string() == 'https://document-session.example/live-successor'
}

@[heap]
struct SessionPreparationObserverProbe {
mut:
	calls                  int
	had_document           bool
	outgoing_owner_visible bool
}

fn test_replacement_preparation_never_publishes_a_session_without_its_document() {
	mut app := document_session_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(document_session_test_page('prepare-outgoing'), false)
	first := app.DocumentSessionRef
	mut outgoing_document := app.document
	probe := &SessionPreparationObserverProbe{}
	mut observer := dom.DocumentObserver.create(mut outgoing_document)
	observer.set_document_became_inactive(fn [app, first, probe] () {
		mut observed := unsafe { &SessionPreparationObserverProbe(probe) }
		observed.calls++
		observed.had_document = app.document != unsafe { nil }
		observed.outgoing_owner_visible = voidptr(app.DocumentSessionRef) == voidptr(first)
			&& voidptr(app.document) == voidptr(first.document)
	})

	app.install_loaded_page(document_session_test_page('prepare-incoming'), false)
	assert probe.calls == 1
	assert probe.had_document
	assert probe.outgoing_owner_visible
	assert voidptr(app.DocumentSessionRef) != voidptr(first)
	assert app.document.url_string() == 'https://document-session.example/prepare-incoming'
	assert first.state == .retired
}
