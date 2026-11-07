module main

import browserbookmarks
import browserhistory
import dom
import gg

$if vox_ui2 ? {
	import ui2
}

fn test_portable_address_bar_ignores_shortcut_characters_and_accepts_altgr() {
	mut app := BrowserApp{ address: 'about:home' }
	app.focus_address_bar()
	app.platform_pointer_modifiers = dom.modifier_ctrl
	app.handle_character(u32(`l`))
	assert app.address == 'about:home'
	assert app.address_select
	app.platform_pointer_modifiers = 0
	for code in 'https://example.test/'.runes() { app.handle_character(u32(code)) }
	assert app.address == 'https://example.test/'
	app.focus_address_bar()
	app.platform_pointer_modifiers = dom.modifier_ctrl | dom.modifier_alt
	app.handle_character(u32(`€`))
	assert app.address == '€'
}

fn test_address_bar_empty_submission_keeps_focus_and_does_not_navigate() {
	mut app := BrowserApp{
		address:        '  \t '
		address_active: true
		address_select: true
	}
	app.submit_address_bar()
	assert app.navigation_generation == 0
	assert app.pending_navigation == none
	assert app.address_active
}

fn test_address_bar_escape_restores_current_history_url() {
	mut app := BrowserApp{
		address:        'unfinished.example'
		address_active: true
		address_select: true
		history:        [HistoryEntry{ url: 'https://current.example/page' }]
		history_index:  0
	}
	app.cancel_address_bar()
	assert app.address == 'https://current.example/page'
	assert !app.address_active
	assert !app.address_select
	assert app.navigation_generation == 0
}

// Visits are recorded oldest first; history lists the newest first.
fn address_suggestion_test_history() &browserhistory.Store {
	now := browserhistory.now()
	mut history := browserhistory.open('', now) or { panic(err) }
	history.record('https://gitlab.com/explore', 'GitLab', now - 86400) or { panic(err) }
	history.record('https://github.com/', 'GitHub', now - 600) or { panic(err) }
	history.record('https://github.com/vlang/v', 'vlang/v', now - 300) or { panic(err) }
	history.record('https://github.com/vlang/v', 'vlang/v: fast language', now - 60) or { panic(err) }
	return history
}

fn test_address_suggestions_merge_history_and_bookmarks_into_candidates() {
	mut app := BrowserApp{ browsing_history: address_suggestion_test_history() }
	app.bookmarks = &browserbookmarks.Store{
		items: [
			browserbookmarks.Bookmark{ url: 'https://github.com/', title: 'Bookmarked GitHub' },
			browserbookmarks.Bookmark{ url: 'https://docs.example.org/guide', title: 'Guide' },
		]
	}
	candidates := app.browser_address_candidates()
	assert candidates.len == 4
	assert candidates[0].url == 'https://github.com/vlang/v'
	assert candidates[0].visits == 2
	assert candidates[0].title == 'vlang/v: fast language'
	assert candidates[1].url == 'https://github.com/' && candidates[1].bookmarked
	assert candidates[1].title == 'GitHub'
	assert candidates[3].url == 'https://docs.example.org/guide'
	assert candidates[3].bookmarked && candidates[3].visits == 0
}

fn test_address_suggestions_complete_inline_open_rows_and_close_with_the_field() {
	mut app := BrowserApp{
		address:          'https://current.example/page'
		history:          [HistoryEntry{ url: 'https://current.example/page' }]
		history_index:    0
		browsing_history: address_suggestion_test_history()
		// Queue navigations instead of fetching them.
		navigation_work_depth: 1
	}
	app.focus_address_bar()
	app.update_address_suggestions('gi')
	assert app.address == 'github.com'
	assert app.address_suggestions_open()
	elements := app.address_suggestion_elements(BrowserChromeState{ width: 800, height: 600 })
	assert elements.len == 1
	assert elements[0].frame.x == address_field_left
	assert elements[0].frame.y == tab_strip_height + address_field_top + address_field_height + 2
	assert elements[0].frame.width == browser_address_field_width(800)
	app.submit_address_bar()
	completed := app.deferred_navigation_input or { panic('Enter did not open the completion') }
	assert completed.address == 'https://github.com/' && completed.add_history
	app.deferred_navigation_input = none
	assert !app.address_suggestions_open()
	assert !app.address_active
	// A deletion keeps the typed text, and Enter searches for it.
	app.focus_address_bar()
	mut state := app.browser_ui()
	state.address_inline_blocked = true
	app.update_address_suggestions('gi')
	assert app.address == 'gi'
	assert !state.address_inline_blocked
	app.submit_address_bar()
	searched := app.deferred_navigation_input or { panic('Enter did not search') }
	assert searched.address == 'https://duckduckgo.com/html/?q=gi'
	app.deferred_navigation_input = none
	// Rows open their own destination; stale dropdown actions are ignored.
	app.focus_address_bar()
	app.update_address_suggestions('vlang')
	stale := app.browser_ui().address_dropdown or { panic('missing dropdown') }
	app.update_address_suggestions('vlang ')
	app.activate_browser_chrome(stale.action(1))
	assert app.deferred_navigation_input == none
	dropdown := app.browser_ui().address_dropdown or { panic('missing dropdown') }
	assert dropdown.suggestions[1].url == 'https://github.com/vlang/v'
	app.activate_browser_chrome(dropdown.action(1))
	clicked := app.deferred_navigation_input or { panic('the row did not navigate') }
	assert clicked.address == 'https://github.com/vlang/v'
	assert app.address == 'github.com/vlang/v'
	app.deferred_navigation_input = none
	assert !app.address_suggestions_open()
	// Restoring the page address and empty text both close the dropdown.
	app.focus_address_bar()
	app.update_address_suggestions('gitl')
	assert app.address == 'gitlab.com'
	app.cancel_address_bar()
	assert !app.address_suggestions_open()
	assert app.address == 'https://current.example/page'
	app.update_address_suggestions('  ')
	assert !app.address_suggestions_open()
}

fn test_browser_debug_uses_command_on_macos_and_control_on_windows() {
	assert browser_debug_modifier(.super | .shift, true)
	assert !browser_debug_modifier(.ctrl, true)
	assert browser_debug_modifier(.ctrl | .shift, false)
	assert !browser_debug_modifier(.super, false)
	assert !browser_debug_modifier(.super, true)
	assert !browser_debug_modifier(.ctrl | .alt, false)
	modifier := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	mut app := BrowserApp{ address: 'unfinished.example', address_active: true }
	assert !app.chrome_debug
	normal_snapshot := app.browser_chrome_snapshot_path('https://example.test/')
	assert normal_snapshot != cached_snapshot_path('https://example.test/')
	app.snapshot_cached = true
	app.snapshot_hold = true
	app.snapshot_hold_until = 1
	app.navigation_work_depth = 1
	app.handle_event(&gg.Event{ typ: .key_down, key_code: .d, modifiers: u32(modifier | .shift) })
	assert app.deferred_page_input.len == 0
	app.handle_key(.d, modifier | .shift)
	assert app.chrome_debug
	assert app.browser_chrome_snapshot_path('https://example.test/') != normal_snapshot
	assert !app.snapshot_cached
	assert !app.snapshot_hold
	assert app.snapshot_hold_until == 0
	assert app.address == 'unfinished.example'
	assert app.address_active
	app.handle_key(.d, modifier | .shift)
	assert !app.chrome_debug
	assert app.browser_chrome_snapshot_path('https://example.test/') == normal_snapshot
}

fn test_browser_debug_row_returns_its_height_to_the_document_when_hidden() {
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><p>Viewport</p>',
		dom.url_about_blank(), none, none, none, 0, false)
	defer { document.finalize() }
	mut app := BrowserApp{ document: document, layout_tree_only: true }
	app.relayout(800, 600)
	assert app.page_top() == 60
	assert app.viewport_height == 516
	assert document.viewport_rect().height == 516
	app.toggle_browser_debug()
	app.relayout(800, 600)
	assert app.page_top() == 92
	assert app.viewport_height == 484
	assert document.viewport_rect().height == 484
	app.toggle_browser_debug()
	app.relayout(800, 600)
	assert app.viewport_height == 516
	assert document.viewport_rect().height == 516
}

$if vox_ui2 ? {
	#include "@VMODROOT/native_address_bar_test_darwin.h"

	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_insert(field voidptr, bytes &u8, length int)
	fn C.native_test_address_submit(field voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_address_geometry(field voidptr, width int) int
	fn C.native_test_address_selection(field voidptr) uint
	fn C.native_test_address_backspace(field voidptr)
	fn C.native_test_address_key(field voidptr, key u16) int
	fn C.native_test_address_selection_location(field voidptr) uint
	fn C.native_test_address_clipboard_begin()
	fn C.native_test_address_clipboard_matches() int
	fn C.native_test_address_clipboard_end()
	fn C.native_test_chrome_click(control voidptr)
	fn C.native_test_chrome_enabled(control voidptr) int
	fn C.native_test_chrome_button(control voidptr) int
	fn C.native_test_chrome_geometry(toolbar voidptr, status voidptr, width int, height int, toolbar_height int) int
	fn C.native_test_chrome_hidden(control voidptr) int
	fn C.native_test_chrome_resize(window voidptr, width int, height int)
	fn C.native_test_chrome_document_hit(window voidptr, toolbar voidptr, status voidptr) int
	fn C.native_test_chrome_unmounted(window voidptr) int

	fn address_bar_test_insert(field voidptr, text string) {
		C.native_test_address_insert(field, text.str, text.len)
	}

	fn address_bar_test_app(parent voidptr) (&BrowserApp, voidptr) {
		mut app := &BrowserApp{
			ctx:           gg.new_context(native_rendering: true)
			address:       'https://current.example/page'
			history:       [HistoryEntry{ url: 'https://current.example/page' }]
			history_index: 0
		}
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		field := app.mount_ui2_chrome(parent, 800, 600) or { panic(err) }
		return app, field
	}

	fn test_ui2_address_bar_native_editing_and_enter_queue_the_typed_url() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.focus_address_bar()
		assert ui2.focused_id() == 'address'
		assert C.native_test_address_selection(field) == uint(app.address.len)
		address_bar_test_insert(field, '  https://ui2-address-bar.invalid/typed  ')
		assert app.address == '  https://ui2-address-bar.invalid/typed  '
		C.native_test_address_submit(field)
		pending := app.pending_navigation or { panic('Enter did not navigate') }
		assert pending.resolved == 'https://ui2-address-bar.invalid/typed'
		assert pending.add_history
		assert app.navigation_generation == 1
		assert ui2.focused_id() == ''
		assert !app.address_active
	}

	fn test_ui2_address_bar_completes_hosts_inline_and_drives_suggestions_with_keys() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.browsing_history = address_suggestion_test_history()
		app.focus_address_bar()
		address_bar_test_insert(field, 'gi')
		assert app.address == 'github.com'
		assert ui2.text('address') == 'github.com'
		assert C.native_test_address_selection_location(field) == 2
		assert C.native_test_address_selection(field) == 8
		assert C.native_test_chrome_hidden(ui2.embedded_browser_control('address-suggestions')) == 0
		assert ui2.focused_id() == 'address'
		// Typing the completion's next character keeps completing.
		address_bar_test_insert(field, 't')
		assert app.address == 'github.com'
		assert C.native_test_address_selection_location(field) == 3
		assert C.native_test_address_selection(field) == 7
		// Backspace removes the selected completion without restoring it.
		assert C.native_test_address_key(field, 51) == 0
		C.native_test_address_backspace(field)
		assert app.address == 'git'
		assert ui2.text('address') == 'git'
		assert C.native_test_address_selection(field) == 0
		// Down shows the next row in the field; Escape returns to the typed text.
		assert C.native_test_address_key(field, 125) == 1
		assert app.address == 'github.com/vlang/v'
		assert ui2.text('address') == app.address
		assert C.native_test_address_selection_location(field) == 18
		assert C.native_test_address_key(field, 53) == 1
		assert app.address == 'git'
		assert ui2.text('address') == 'git'
		assert ui2.focused_id() == 'address'
		assert C.native_test_address_key(field, 126) == 1
		assert app.address == 'gitlab.com/explore'
		assert C.native_test_address_key(field, 125) == 1
		assert app.address == 'git'
		assert C.native_test_address_key(field, 125) == 1
		C.native_test_address_submit(field)
		pending := app.pending_navigation or { panic('Enter did not open the selected row') }
		assert pending.resolved == 'https://github.com/vlang/v'
		assert ui2.embedded_browser_control('address-suggestions') == unsafe { nil }
		assert ui2.focused_id() == ''
		// A native row click opens its destination.
		app.focus_address_bar()
		address_bar_test_insert(field, 'explore')
		C.native_test_chrome_click(ui2.embedded_browser_control('address-suggestion-row-1'))
		clicked := app.pending_navigation or { panic('the row did not navigate') }
		assert clicked.resolved == 'https://gitlab.com/explore'
		assert ui2.embedded_browser_control('address-suggestions') == unsafe { nil }
		// Escape with the default row keeps restoring the page address.
		app.focus_address_bar()
		address_bar_test_insert(field, 'gi')
		assert C.native_test_address_key(field, 53) == 1
		assert app.address == 'https://current.example/page'
		assert ui2.embedded_browser_control('address-suggestions') == unsafe { nil }
	}

	fn test_ui2_zoom_shortcuts_preserve_native_address_text_selection_and_focus() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.focus_address_bar()
		address_bar_test_insert(field, 'https://example.test/unfinished')
		app.focus_address_bar()
		for key in [u16(24), 69, 81] {
			assert C.native_test_address_shortcut(field, app, address_bar_shortcut, key, 1) == 1
			assert app.page_zoom == 1.1
			assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 29, 0) == 1
			assert app.page_zoom == 1
		}
		for key in [u16(27), 78] {
			assert C.native_test_address_shortcut(field, app, address_bar_shortcut, key, 0) == 1
			assert app.page_zoom == 0.9
			assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 82, 0) == 1
			assert app.page_zoom == 1
		}
		assert app.address == 'https://example.test/unfinished'
		assert ui2.text('address') == app.address
		assert C.native_test_address_selection(field) == uint(app.address.len)
		assert ui2.focused_id() == 'address'
		assert app.address_active && app.address_select
		app.blur_address_bar()
		assert C.native_test_address_shortcut(field, app, address_bar_shortcut, 24, 0) == 1
		assert app.page_zoom == 1.1
		assert ui2.focused_id() == ''
	}

	fn test_ui2_address_bar_enter_reads_the_live_control_and_resize_preserves_edits() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.focus_address_bar()
		address_bar_test_insert(field, 'https://ui2-address-bar.invalid/enter')
		app.resize_address_bar(1000)
		assert C.native_test_address_geometry(field, 862) == 1
		assert ui2.focused_id() == 'address'
		assert ui2.text('address') == app.address
		// Imperative native replacement need not deliver a change notification.
		ui2.set_text('address', 'https://ui2-address-bar.invalid/live')
		C.native_test_address_submit(field)
		pending := app.pending_navigation or { panic('Enter did not navigate') }
		assert pending.resolved == 'https://ui2-address-bar.invalid/live'
		assert pending.add_history
		assert app.navigation_generation == 1
	}

	fn test_ui2_address_bar_shortcuts_unicode_delete_escape_and_url_sync() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 37, 0)
		assert ui2.focused_id() == 'address'
		address_bar_test_insert(field, 'https://example.test/привет/🌍')
		assert app.address == 'https://example.test/привет/🌍'
		C.native_test_address_backspace(field)
		assert app.address == 'https://example.test/привет/'
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 0, 0)
		assert C.native_test_address_selection(field) > 0
		address_bar_test_insert(field, 'replacement')
		assert app.address == 'replacement'
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 53, 0)
		assert app.address == 'https://current.example/page'
		assert ui2.text('address') == app.address
		assert ui2.focused_id() == ''
		assert app.navigation_generation == 0
		app.address = 'https://redirect.example/final'
		app.sync_address_bar()
		assert ui2.text('address') == 'https://redirect.example/final'
	}

	fn test_ui2_address_bar_clipboard_shortcuts_replace_copy_and_cut_the_selection() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		C.native_test_address_clipboard_begin()
		defer {
			C.native_test_address_clipboard_end()
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 37, 0)
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 9, 0)
		assert app.address == 'https://ui2-address-bar.invalid/pasted'
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 0, 0)
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 8, 0)
		assert C.native_test_address_clipboard_matches() == 1
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 7, 0)
		assert app.address == ''
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 9, 0)
		assert app.address == 'https://ui2-address-bar.invalid/pasted'
	}

	fn test_ui2_chrome_uses_native_buttons_with_history_enabled_states_and_actions() {
		window := C.native_test_address_window()
		mut app, _ := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		assert ui2.embedded_browser_control('go') == unsafe { nil }
		for id in ['back', 'forward', 'reload'] {
			assert C.native_test_chrome_button(ui2.embedded_browser_control(id)) == 1
		}
		assert C.native_test_chrome_enabled(ui2.embedded_browser_control('back')) == 0
		assert C.native_test_chrome_enabled(ui2.embedded_browser_control('forward')) == 0
		assert C.native_test_chrome_enabled(ui2.embedded_browser_control('reload')) == 1
		C.native_test_chrome_click(ui2.embedded_browser_control('back'))
		assert app.navigation_generation == 0
		app.history << HistoryEntry{ url: 'https://next.example/page' }
		app.update_browser_chrome(800, 600)
		assert C.native_test_chrome_enabled(ui2.embedded_browser_control('forward')) == 1
		// Native actions use the same navigation guard as pointer/keyboard input.
		app.navigation_work_depth = 1
		C.native_test_chrome_click(ui2.embedded_browser_control('forward'))
		forward := app.deferred_navigation_input or { panic('Forward did not dispatch') }
		assert forward.is_history && forward.history_delta == 1
		app.deferred_navigation_input = none
		app.history_index = 1
		app.update_browser_chrome(800, 600)
		assert C.native_test_chrome_enabled(ui2.embedded_browser_control('back')) == 1
		assert C.native_test_chrome_enabled(ui2.embedded_browser_control('forward')) == 0
		C.native_test_chrome_click(ui2.embedded_browser_control('back'))
		back := app.deferred_navigation_input or { panic('Back did not dispatch') }
		assert back.is_history && back.history_delta == -1
		app.deferred_navigation_input = none
		C.native_test_chrome_click(ui2.embedded_browser_control('reload'))
		reload := app.deferred_navigation_input or { panic('Reload did not dispatch') }
		assert reload.address == 'https://next.example/page'
		assert !reload.add_history
		app.deferred_navigation_input = none
		assert ui2.embedded_browser_control('home') == unsafe { nil }
	}

	fn test_ui2_chrome_resize_and_status_refresh_preserve_editing_and_document_input() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.focus_address_bar()
		address_bar_test_insert(field, 'https://editing.example/привет')
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 0, 0)
		selection := C.native_test_address_selection(field)
		app.status = 'Loaded'
		app.hovered_link = 'https://hover.example/'
		C.native_test_chrome_resize(window, 1000, 700)
		app.update_browser_chrome(1000, 700)
		assert ui2.embedded_browser_control('address') == field
		assert C.native_test_address_geometry(field, 862) == 1
		assert ui2.focused_id() == 'address'
		assert ui2.text('address') == 'https://editing.example/привет'
		assert C.native_test_address_selection(field) == selection
		assert ui2.text('load-status') == 'Loaded'
		assert C.native_test_chrome_hidden(ui2.embedded_browser_control('load-status')) == 1
		assert ui2.text('footer') == 'https://hover.example/'
		assert C.native_test_chrome_geometry(ui2.embedded_browser_control('toolbar'), ui2.embedded_browser_control('status-bar'), 1000, 700, 60) == 1
		assert C.native_test_chrome_document_hit(window, ui2.embedded_browser_control('toolbar'), ui2.embedded_browser_control('status-bar')) == 1
		app.hovered_link = ''
		app.js_messages << 'first line\nstack line'
		app.update_browser_chrome(1000, 700)
		assert ui2.text('footer') == 'Console: first line'
		app.sample_browser_memory_chrome()
		assert ui2.text('memory').starts_with('RAM: ')
		assert !app.memory_status.sampled
	}

	fn test_ui2_hidden_scroll_diagnostics_keep_controls_until_debug_is_shown() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		hidden_status := ui2.text('load-status')
		for y in 1 .. 20 {
			app.status = 'scroll y=${y}'
			app.update_browser_chrome(800, 600)
			assert app.browser_chrome.status == app.status
			assert ui2.text('load-status') == hidden_status
			assert ui2.embedded_browser_control('address') == field
		}
		app.toggle_browser_debug()
		assert ui2.text('load-status') == 'scroll y=19'
		assert C.native_test_chrome_hidden(ui2.embedded_browser_control('load-status')) == 0
		app.status = 'scroll y=20'
		app.update_browser_chrome(800, 600)
		assert ui2.text('load-status') == app.status
	}

	fn test_ui2_chrome_unmount_clears_controls_and_sampling_and_can_mount_again() {
		window := C.native_test_address_window()
		mut app, _ := address_bar_test_app(C.native_test_address_parent(window))
		app.unmount_address_bar()
		assert C.native_test_chrome_unmounted(window) == 1
		assert ui2.embedded_browser_control('address') == unsafe { nil }
		assert ui2.embedded_browser_control('home') == unsafe { nil }
		mut next, _ := address_bar_test_app(C.native_test_address_parent(window))
		assert ui2.embedded_browser_control('back') != unsafe { nil }
		next.unmount_address_bar()
		assert C.native_test_chrome_unmounted(window) == 1
		C.native_test_address_close(window)
	}

	fn test_ui2_debug_shortcut_toggles_diagnostics_from_address_and_page_focus() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.status = 'HTTP 200 · 422405 bytes · 2539 paints · 1024×656 CSS px'
		app.update_browser_chrome(800, 600)
		assert !app.chrome_debug
		assert C.native_test_chrome_hidden(ui2.embedded_browser_control('load-status')) == 1
		app.focus_address_bar()
		address_bar_test_insert(field, 'https://editing.example/')
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 0, 0)
		selection := C.native_test_address_selection(field)
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 2, 1)
		assert app.chrome_debug
		assert C.native_test_chrome_hidden(ui2.embedded_browser_control('load-status')) == 0
		assert ui2.text('load-status') == app.status
		assert C.native_test_chrome_geometry(ui2.embedded_browser_control('toolbar'), ui2.embedded_browser_control('status-bar'), 800, 600, 92) == 1
		assert ui2.focused_id() == 'address'
		assert C.native_test_address_selection(field) == selection
		assert app.address == 'https://editing.example/'
		app.blur_address_bar()
		C.native_test_address_shortcut(field, app, address_bar_shortcut, 2, 1)
		assert !app.chrome_debug
		assert C.native_test_chrome_hidden(ui2.embedded_browser_control('load-status')) == 1
		assert C.native_test_chrome_geometry(ui2.embedded_browser_control('toolbar'), ui2.embedded_browser_control('status-bar'), 800, 600, 60) == 1
		assert app.navigation_generation == 0
	}
}
