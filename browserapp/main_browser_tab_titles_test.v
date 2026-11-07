module main

import browsersettings
import browsertabs
import gg
import os
import time
import ui2

$if vox_ui2 ? {
	#include "@VMODROOT/native_browser_tab_titles_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.native_test_tab_rename(voidptr) int
	fn C.native_test_address_submit(voidptr)
	fn C.native_test_chrome_click(voidptr)
	fn C.native_test_address_shortcut(voidptr, voidptr, fn (voidptr, int), u16, int) int
	fn C.ui2_test_tabs_capture(voidptr, &u8) int
}

fn test_mounted_tab_rename_targets_owner_survives_navigation_and_can_reset_or_cancel() {
	$if vox_ui2 ? {
		directory := os.join_path(os.temp_dir(), 'vox-rename-${os.getpid()}-${time.sys_mono_now()}')
		browsersettings.initialize(os.join_path(directory, 'settings.json'))!
		window := C.native_test_address_window()
		mut app := &BrowserApp{ ctx: &gg.Context{}, address: 'https://first.test/' }
		app.initialize_browser_tabs()
		mut second := &BrowserApp{ ctx: app.ctx, tabs: app.tabs, address: 'https://second.test/' }
		app.tabs.pages << second
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
			os.rmdir_all(directory) or {}
		}
		first_id := app.browser_tab_identity(0)
		second_id := app.browser_tab_identity(1)
		assert C.native_test_tab_rename(ui2.embedded_browser_control('tab-1')) == 0
		app.activate_browser_chrome('tab-rename:${second_id}')
		assert app.browser_ui().tab_title_editor == none
		browsersettings.save(browsersettings.Proxy{ enable_custom_tab_titles: true, enable_tab_coloring: true })!
		app.refresh_browser_ui()
		assert C.native_test_tab_rename(ui2.embedded_browser_control('tab-1')) == 1
		editor := app.browser_ui().tab_title_editor or { panic('missing rename editor') }
		assert ui2.focused_id() == editor.input_id()
		assert ui2.text(editor.input_id()) == 'https://second.test/'
		if capture := os.getenv_opt('VOX_TAB_TITLE_CAPTURE') {
			assert C.ui2_test_tabs_capture(ui2.embedded_browser_control('tab-title-overlay-${editor.token}'), capture.str) == 1
		}
		ui2.set_text(editor.input_id(), '  Research — 資料\n2026  ')
		// Keep the active tab at index zero while moving the target's owner.
		app.tabs.pages = [app, &BrowserApp{ ctx: app.ctx, tabs: app.tabs }, second]
		app.snapshot_cached = true
		C.native_test_chrome_click(ui2.embedded_browser_control('tab-title-save'))
		assert second.browser_ui().custom_tab_title == 'Research — 資料 2026'
		assert app.browser_ui().custom_tab_title == ''
		assert app.browser_chrome_state(800, 600).tab_titles[2] == 'Research — 資料 2026'
		assert !app.snapshot_cached && app.browser_ui().tab_title_editor == none
		second.address = 'https://second.test/navigated'
		assert second.detached_tab_session().custom_title == 'Research — 資料 2026'
		assert second.browser_tab_title() == 'https://second.test/navigated'
		assert app.browser_chrome_state(800, 600).tab_titles[2] == 'Research — 資料 2026'
		app.activate_browser_chrome('tab-rename:${second_id}')
		cancelled := app.browser_ui().tab_title_editor or { panic('missing editor') }
		ui2.set_text(cancelled.input_id(), 'Discarded')
		assert C.native_test_address_shortcut(ui2.embedded_browser_control(cancelled.input_id()), app, address_bar_shortcut, 53, 0) != 0
		assert app.browser_ui().tab_title_editor == none
		assert second.browser_ui().custom_tab_title == 'Research — 資料 2026'
		app.activate_browser_chrome('tab-rename:${first_id}')
		current := app.browser_ui().tab_title_editor or { panic('missing editor') }
		ui2.set_text(current.input_id(), 'First custom')
		app.activate_browser_chrome(cancelled.action('save'))
		assert app.browser_ui().custom_tab_title == ''
		C.native_test_address_submit(ui2.embedded_browser_control(current.input_id()))
		assert app.browser_ui().custom_tab_title == 'First custom'
		app.activate_browser_chrome('tab-rename:${first_id}')
		C.native_test_chrome_click(ui2.embedded_browser_control('tab-title-reset'))
		assert app.browser_ui().custom_tab_title == ''
		app.activate_browser_chrome('tab-rename:${first_id}')
		browser_ui_event('settings-open')
		assert app.browser_ui().tab_title_editor == none
		close_browser_settings()
		app.activate_browser_chrome('tab-rename:${second_id}')
		browsersettings.save(browsersettings.Proxy{ enable_tab_coloring: true })!
		app.refresh_browser_ui()
		assert app.browser_chrome.tab_titles[2] == second.address
		C.native_test_chrome_click(ui2.embedded_browser_control('tab-title-save'))
		assert second.browser_ui().custom_tab_title == 'Research — 資料 2026'
		assert app.browser_ui().tab_title_editor == none
		browsersettings.save(browsersettings.Proxy{ enable_custom_tab_titles: true })!
		app.activate_browser_chrome('tab-rename:${second_id}')
		app.tabs.pages.delete(2)
		C.native_test_chrome_click(ui2.embedded_browser_control('tab-title-save'))
		assert app.browser_ui().custom_tab_title == ''
		assert app.browser_ui().tab_title_editor == none
		app.tabs.pages << second
		assert app.browser_chrome_state(800, 600).tab_titles[2] == 'Research — 資料 2026'
		app.activate_browser_chrome('tab-rename:${second_id}')
		blank := app.browser_ui().tab_title_editor or { panic('missing editor') }
		ui2.set_text(blank.input_id(), '   ')
		app.activate_browser_chrome(blank.action('save'))
		assert second.browser_ui().custom_tab_title == ''
	}
}

fn test_process_display_titles_toggle_without_replacing_the_page_title() {
	directory := os.join_path(os.temp_dir(), 'vox-process-rename-${os.getpid()}-${time.sys_mono_now()}')
	browsersettings.initialize(os.join_path(directory, 'settings.json'))!
	mut session := browsertabs.create(browsertabs.Frame{})!
	defer {
		session.leave() or {}
		os.rmdir_all(directory) or {}
	}
	session.poll('Original page', 'https://example.test', '', true)!
	mut app := &BrowserApp{ tabs: &BrowserTabs{ session: session } }
	session.set_custom_title(session.id, 'Custom name')!
	assert app.browser_chrome_state(800, 600).tab_titles == ['Original page']
	browsersettings.save(browsersettings.Proxy{ enable_custom_tab_titles: true })!
	assert app.browser_chrome_state(800, 600).tab_titles == ['Custom name']
	session.poll('New page title', 'https://example.test/next', '', true)!
	assert app.browser_chrome_state(800, 600).tab_titles == ['Custom name']
	browsersettings.save(browsersettings.Proxy{})!
	assert app.browser_chrome_state(800, 600).tab_titles == ['New page title']
}
