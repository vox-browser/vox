module main

import dom
import html
import os
import page

fn back_forward_cache_test_app() &BrowserApp {
	return &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		viewport_width:  800
		viewport_height: 600
	}
}

fn back_forward_cache_test_page(name string) LoadedPage {
	return LoadedPage{
		url:          'https://bfcache.example/${name}'
		markup:       '<!doctype html><title>${name}</title><style>body{margin:0}#tall{height:4000px}</style><input id="field" value="initial"><div id="tall">${name}</div>'
		content_type: 'text/html'
	}
}

@[heap]
struct BackForwardCacheEventLog {
mut:
	entries []string
}

fn back_forward_cache_test_window_events(document &dom.Document) &BackForwardCacheEventLog {
	window := document.get_window() or { panic('missing Window') }
	log := &BackForwardCacheEventLog{}
	for name in ['pagehide', 'pageshow'] {
		listener := dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [log] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut owner := unsafe { log }
				transition := unsafe { &dom.PageTransitionEvent(event) }
				owner.entries << '${event.type_name()}:${transition.persisted()}'
				return dom.js_undefined()
			}
		})
		unsafe { &dom.EventTarget(window) }.add_event_listener_without_options(name, listener)
	}
	return log
}

// Run the queued load task, after which the page is showing.
fn back_forward_cache_test_finish_loading(document &dom.Document) {
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		if document.document_page_showing() { return }
		event_loop.process()
	}
	assert document.document_page_showing()
}

@[heap]
struct BackForwardCacheTaskProbe {
mut:
	ran bool
}

fn test_back_and_forward_reactivate_the_same_documents_with_their_state() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(back_forward_cache_test_page('first'), true)
	first := app.document
	first_window := first.get_window() or { panic('missing Window') }
	field := first.get_element_by_id('field') or { panic('missing field') }
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(field) })
	model.set_value('typed before leaving') or { panic(err) }
	app.relayout(app.viewport_width, app.viewport_height + app.chrome_height())
	app.set_scroll_y(700, app.viewport_height + app.chrome_height())
	assert app.scroll_y == 700
	layout_passes := first.layout_pass_generation
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	second := app.document
	assert voidptr(second) != voidptr(first)
	assert app.back_forward_cache.pages.len == 1
	assert !first.is_fully_active()
	assert !first.has_been_destroyed()
	// The cached page keeps its layout.
	assert first.layout_engine_handle() != unsafe { nil }
	assert first.layout_node() != none
	assert app.scroll_y == 0

	app.history_go(-1)
	assert voidptr(app.document) == voidptr(first)
	assert app.document.is_fully_active()
	assert app.document.url_string() == 'https://bfcache.example/first'
	assert app.address == 'https://bfcache.example/first'
	window := app.document.get_window() or { panic('missing Window') }
	assert voidptr(window) == voidptr(first_window)
	restored_field := app.document.get_element_by_id('field') or { panic('missing field') }
	assert voidptr(restored_field) == voidptr(field)
	assert html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(restored_field) }).value() == 'typed before leaving'
	assert app.scroll_y == 700
	assert app.content_height > 700
	// Showing it again lays nothing out.
	assert app.document.layout_pass_generation == layout_passes
	assert app.paint_commands.len > 0
	// The page left by going back is kept for going forward.
	assert !second.is_fully_active()
	assert app.back_forward_cache.pages.len == 1

	app.history_go(1)
	assert voidptr(app.document) == voidptr(second)
	assert app.document.is_fully_active()
	assert app.history_index == 1
	assert app.back_forward_cache.pages.len == 1
}

fn test_cached_pages_receive_persisted_page_transition_events() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(back_forward_cache_test_page('first'), true)
	back_forward_cache_test_finish_loading(app.document)
	events := back_forward_cache_test_window_events(app.document)
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	assert events.entries == ['pagehide:true']
	assert app.back_forward_cache.pages[0].document.visibility_state() == 'hidden'
	app.history_go(-1)
	assert events.entries == ['pagehide:true', 'pageshow:true']
	assert app.document.visibility_state() == 'visible'
	assert app.document.document_page_showing()
}

fn test_a_cached_page_runs_no_tasks_until_it_is_shown_again() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(back_forward_cache_test_page('first'), true)
	back_forward_cache_test_finish_loading(app.document)
	first := app.document
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	probe := &BackForwardCacheTaskProbe{}
	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), first, fn [probe] () {
		mut owner := unsafe { probe }
		owner.ran = true
	})
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 10 { event_loop.process() }
	assert !probe.ran
	app.history_go(-1)
	assert voidptr(app.document) == voidptr(first)
	for _ in 0 .. 10 {
		if probe.ran { break }
		event_loop.process()
	}
	assert probe.ran
}

fn test_a_page_left_before_its_load_event_gets_load_instead_of_pageshow() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(back_forward_cache_test_page('first'), true)
	first := app.document
	assert !first.document_page_showing()
	events := back_forward_cache_test_window_events(first)
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	app.history_go(-1)
	assert voidptr(app.document) == voidptr(first)
	assert events.entries == []
	back_forward_cache_test_finish_loading(first)
	assert events.entries == []
}

fn test_a_new_navigation_discards_forward_pages() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(back_forward_cache_test_page('first'), true)
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	second := app.document
	app.history_go(-1)
	assert app.back_forward_cache.pages.len == 1
	assert voidptr(app.back_forward_cache.pages[0].document) == voidptr(second)
	app.install_loaded_page(back_forward_cache_test_page('third'), true)
	assert app.history.len == 2
	// The second page's entry was replaced; only the first page is kept.
	assert app.back_forward_cache.pages.len == 1
	assert app.back_forward_cache.pages[0].history_index == 0
	app.history_go(-1)
	assert app.document.url_string() == 'https://bfcache.example/first'
	app.history_go(1)
	assert app.document.url_string() == 'https://bfcache.example/third'
}

fn test_the_cache_keeps_the_most_recent_pages() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	mut documents := []voidptr{}
	for index in 0 .. back_forward_cache_capacity + 3 {
		app.install_loaded_page(back_forward_cache_test_page('page${index}'), true)
		documents << voidptr(app.document)
	}
	assert app.back_forward_cache.pages.len == back_forward_cache_capacity
	assert app.back_forward_cache.pages[0].history_index == 2
	app.history_go(-1)
	assert voidptr(app.document) == documents[documents.len - 2]
	// An evicted page is parsed again from its entry.
	app.history_go(-(documents.len - 2))
	assert app.history_index == 0
	assert app.document.url_string() == 'https://bfcache.example/page0'
	assert voidptr(app.document) != documents[0]
	assert app.back_forward_cache.pages.len <= back_forward_cache_capacity
}

fn test_reinstalled_entries_and_reloads_are_not_restored_from_stale_pages() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(back_forward_cache_test_page('first'), true)
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	second := app.document
	// A reload installs a fresh document and does not cache the old one.
	app.install_loaded_page(back_forward_cache_test_page('second'), false)
	assert voidptr(app.document) != voidptr(second)
	assert app.back_forward_cache.pages.len == 1
	assert app.back_forward_cache.pages[0].history_index == 0
	// An entry whose markup changed belongs to a different page.
	app.history[0] = HistoryEntry{
		url:          app.history[0].url
		markup:       '<!doctype html><title>changed</title>'
		content_type: 'text/html'
	}
	cached_first := app.back_forward_cache.pages[0].document
	app.history_go(-1)
	assert voidptr(app.document) != voidptr(cached_first)
	assert app.document.title() == 'changed'
}

fn test_internal_and_error_pages_are_not_cached() {
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:          'https://bfcache.example/missing'
		markup:       error_markup('https://bfcache.example/missing', 'offline')
		status:       'Navigation error'
		content_type: 'text/html'
	}, true)
	app.install_loaded_page(back_forward_cache_test_page('after-error'), true)
	assert app.back_forward_cache.pages.len == 0
	app.install_loaded_page(LoadedPage{
		url:          browser_new_tab_url
		content_type: 'text/html'
		status:       'New Tab'
	}, true)
	assert app.back_forward_cache.pages.len == 1
	app.install_loaded_page(back_forward_cache_test_page('after-new-tab'), true)
	assert app.back_forward_cache.pages.len == 1
	assert app.back_forward_cache.pages[0].entry_url == 'https://bfcache.example/after-error'
}

fn test_a_cached_page_keeps_its_script_realm() {
	$if !darwin {
		return
	}
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:          'https://bfcache.example/script'
		markup:       '<!doctype html><title>script</title><p id="out">initial</p><script>window.visits=1</script>'
		content_type: 'text/html'
	}, true)
	runtime := app.js_runtime
	assert runtime != unsafe { nil }
	assert app.js_runtime.evaluate_host('visits+=41,document.getElementById("out").textContent="changed",visits')! == '42'
	app.js_runtime.mark_document_state_dirty()
	app.poll_javascript_tasks()
	assert (app.document.get_element_by_id('out') or { panic('missing #out') }).as_node().text_content() or { '' } == 'changed'
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	assert voidptr(app.js_runtime) != voidptr(runtime)
	app.history_go(-1)
	assert voidptr(app.js_runtime) == voidptr(runtime)
	assert app.js_runtime.evaluate_host('visits')! == '42'
	out := app.document.get_element_by_id('out') or { panic('missing #out') }
	assert out.as_node().text_content() or { '' } == 'changed'
}

fn test_a_script_navigation_that_left_a_cached_page_is_not_replayed() {
	$if !darwin {
		return
	}
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:          'https://bfcache.example/leaving'
		markup:       '<!doctype html><title>leaving</title><script>window.left=0</script>'
		content_type: 'text/html'
	}, true)
	leaving := app.document
	// The page leaves through location.href, which navigates through the shell.
	destination := 'file:///tmp/vox-bfcache-missing-${os.getpid()}.html'
	app.js_runtime.evaluate_host('left++,location.href="${destination}"')!
	app.js_runtime.mark_document_state_dirty()
	app.poll_javascript_tasks()
	assert app.history.len == 2
	assert app.document.url_string() == destination
	app.history_go(-1)
	assert voidptr(app.document) == voidptr(leaving)
	assert app.history.len == 2
	assert app.history_index == 0
	assert app.js_runtime.evaluate_host('left')! == '1'
}

fn test_cached_page_scripts_can_read_persisted_on_real_lifecycle_events() {
	$if !darwin { return }
	mut app := back_forward_cache_test_app()
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:          'https://bfcache.example/persisted'
		markup:       '<!doctype html><title>persisted</title><script>window.transitions=[];for(const name of ["pagehide","pageshow"])addEventListener(name,event=>transitions.push([event.type,event.persisted,event instanceof PageTransitionEvent,event.isTrusted,event.target===document]));</script>'
		content_type: 'text/html'
	}, true)
	first := app.document
	back_forward_cache_test_finish_loading(first)
	// Record the cache transitions independently of initial load delivery.
	app.js_runtime.evaluate_host('transitions=[]')!
	app.install_loaded_page(back_forward_cache_test_page('second'), true)
	app.history_go(-1)
	assert voidptr(app.document) == voidptr(first)
	assert app.js_runtime.evaluate_host('JSON.stringify(transitions)')! == '[["pagehide",true,true,true,true],["pageshow",true,true,true,true]]'
	app.history_go(1)
	app.history_go(-1)
	assert voidptr(app.document) == voidptr(first)
	assert app.js_runtime.evaluate_host('JSON.stringify(transitions.slice(-2))')! == '[["pagehide",true,true,true,true],["pageshow",true,true,true,true]]'
}
