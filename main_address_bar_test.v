module main

import dom

fn test_portable_address_bar_ignores_shortcut_characters_and_accepts_altgr() {
	mut app := BrowserApp{address: 'about:home'}
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

$if vox_ui2 ? {
	import gg
	import ui2
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

$if vox_ui2 ? {
	#include "native_address_bar_test_darwin.h"

	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_address_insert(field voidptr, bytes &u8, length int)
	fn C.native_test_address_submit(field voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int)
	fn C.native_test_address_geometry(field voidptr, width int) int
	fn C.native_test_address_selection(field voidptr) usize
	fn C.native_test_address_backspace(field voidptr)
	fn C.native_test_address_clipboard_begin()
	fn C.native_test_address_clipboard_matches() int
	fn C.native_test_address_clipboard_end()

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
		field := ui2.mount_embedded_textbox(parent, ui2.rect(184, 12, 548, 34), app.address,
			address_bar_event) or { panic(err) }
		app.native_address_bar = true
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
		assert C.native_test_address_selection(field) == usize(app.address.len)
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

	fn test_ui2_address_bar_go_reads_the_live_control_and_resize_preserves_edits() {
		window := C.native_test_address_window()
		mut app, field := address_bar_test_app(C.native_test_address_parent(window))
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		app.focus_address_bar()
		address_bar_test_insert(field, 'https://ui2-address-bar.invalid/go')
		app.resize_address_bar(1000)
		assert C.native_test_address_geometry(field, 748) == 1
		assert ui2.focused_id() == 'address'
		assert ui2.text('address') == app.address
		// Imperative native replacement need not deliver a change notification.
		ui2.set_text('address', 'https://ui2-address-bar.invalid/live')
		app.handle_click(f32(browser_window_size().width - 36), 24)
		pending := app.pending_navigation or { panic('Go did not navigate') }
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
}
