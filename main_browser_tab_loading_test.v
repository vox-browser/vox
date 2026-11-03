module main

import browsertabs
import dom
import html
import platform

$if vox_ui2 ? {
	import ui2
	#include "native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
}

fn tab_loading_test_app() &BrowserApp {
	mut document := dom.Document.create(dom.URL{ value: 'https://loading.test/' })
	html.parse_html_from_a_string(document, '<!doctype html><title>Loading fixture</title>')
	document.update_readiness(.complete)
	return &BrowserApp{ document: document, navigation_generation: 2 }
}

fn test_tab_loading_covers_navigation_dependencies_and_document_load_then_stops() {
	mut app := tab_loading_test_app()
	defer { app.document.finalize() }
	assert !app.browser_document_loading()
	app.pending_navigation = PendingNavigation{ generation: 2 }
	assert app.browser_document_loading()
	app.pending_navigation = PendingNavigation{ generation: 1 }
	assert !app.browser_document_loading()
	app.pending_navigation = none
	app.navigation_fetch_generation = 2
	assert app.browser_document_loading()
	app.navigation_fetch_generation = 1
	assert !app.browser_document_loading()
	app.pending_page_preload = PendingPagePreload{ generation: 2 }
	assert app.browser_document_loading()
	app.pending_page_preload = none
	app.document.update_readiness(.loading)
	assert app.browser_document_loading()
	app.document.update_readiness(.interactive)
	assert app.browser_document_loading()
	app.document.update_readiness(.complete)
	app.document.increment_number_of_things_delaying_the_load_event()
	assert app.browser_document_loading()
	app.document.decrement_number_of_things_delaying_the_load_event()
	assert !app.browser_document_loading()
	// An error document finishes just like a successful response.
	app.load_status = 'Navigation error'
	assert !app.browser_document_loading()
}

fn test_tab_loading_tracks_local_page_owners_after_reorder_and_remote_process_metadata() {
	mut first := tab_loading_test_app()
	mut second := tab_loading_test_app()
	defer {
		first.document.finalize()
		second.document.finalize()
	}
	first.initialize_browser_tabs()
	first.tabs.pages << second
	second.navigation_fetch_generation = second.navigation_generation
	assert first.browser_tab_loading_states() == [false, true]
	first.tabs.pages = [second, first]
	assert first.browser_tab_loading_states() == [true, false]
	first.tabs.session = &browsertabs.Session{
		id:    'local'
		state: browsertabs.State{
			tabs: [
				browsertabs.Tab{ id: 'remote', loading: true },
				browsertabs.Tab{ id: 'local', loading: true },
			]
		}
	}
	// Local readiness supersedes the last published value; background state is shared.
	assert first.browser_tab_loading_states() == [true, false]
	first.navigation_fetch_generation = first.navigation_generation
	assert first.browser_tab_loading_states() == [true, true]
}

fn test_tab_loading_snapshots_survive_frame_scratch_and_remain_immutable() {
	mut app := tab_loading_test_app()
	defer { app.document.finalize() }
	mut scratch := platform.new_arena('tab loading state fixture')
	defer { scratch.release() }
	token := scratch.enter()
	before := app.browser_tab_loading_states()
	scratch.leave(token)
	scratch.reset()
	assert before == [false]
	assert app.browser_tab_loading_states().data == before.data
	app.navigation_fetch_generation = app.navigation_generation
	after := app.browser_tab_loading_states()
	assert after == [true] && before == [false]
	assert after.data != before.data
	app.navigation_fetch_generation = 0
	assert app.browser_tab_loading_states() == [false]
	assert after == [true]
}

fn test_loading_animation_timer_refreshes_icons_and_stops_on_completion_and_unmount() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		mut app := tab_loading_test_app()
		defer {
			app.unmount_address_bar()
			app.document.finalize()
			C.native_test_address_close(window)
		}
		app.document.update_readiness(.loading)
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		timer := app.browser_ui().tab_loading_timer
		assert timer != unsafe { nil } && timer.is_active()
		address := ui2.embedded_browser_control('address')
		paint_count := app.paint_commands.len
		timer.fire()
		assert app.browser_ui().tab_loading_frame == 1
		assert ui2.embedded_browser_control('address') == address
		assert app.paint_commands.len == paint_count
		app.document.update_readiness(.complete)
		timer.fire()
		assert !timer.is_active()
		assert app.browser_chrome.tab_loading == [false]
		app.document.update_readiness(.loading)
		app.update_browser_chrome(800, 600)
		assert timer.is_active()
		app.unmount_address_bar()
		assert !timer.is_active()
	}
}
