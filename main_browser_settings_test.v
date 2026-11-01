module main

import browsersettings
import gg
import os
import time

$if vox_ui2 ? {
	import ui2
	#include "native_browser_settings_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_chrome_click(control voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
	fn C.native_test_chrome_enabled(control voidptr) int
}

fn test_settings_shortcut_uses_the_platform_command_modifier() {
	command := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	assert is_browser_settings_shortcut(.comma, command)
	assert !is_browser_settings_shortcut(.comma, command | .shift)
	assert !is_browser_settings_shortcut(.period, command)
}

fn test_ui2_settings_apply_cancel_validation_and_toolbar_reconciliation() {
	$if vox_ui2 ? {
		directory := os.join_path(os.temp_dir(), 'vox-ui2-settings-${os.getpid()}-${time.sys_mono_now()}')
		path := os.join_path(directory, 'settings.json')
		browsersettings.initialize(path)!
		window := C.native_test_address_window()
		mut app := &BrowserApp{}
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
			os.rmdir_all(directory) or {}
		}
		show_browser_settings()
		assert browser_settings_visible()
		assert !ui2.control_checked('settings-allow-any-site')
		assert ui2.text('settings-browsing-note').contains('may render slowly')
		host := ui2.embedded_browser_control('settings-host')
		assert C.native_test_chrome_enabled(host) == 0
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-enabled'))
		assert C.native_test_chrome_enabled(host) != 0
		ui2.set_text('settings-host', 'localhost')
		ui2.set_text('settings-port', 'bad')
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-apply'))
		assert browser_settings_visible()
		assert ui2.text('settings-error').contains('65535')
		assert !os.exists(path)
		app.update_browser_chrome(900, 600)
		assert ui2.embedded_browser_control('settings-host') == host
		show_browser_settings()
		assert ui2.text('settings-port') == 'bad'
		ui2.set_text('settings-port', '9050')
		ui2.set_text('settings-sites', 'https://example.com')
		browser_settings_event('settings-apply')
		assert ui2.text('settings-error').contains('hostnames')
		ui2.set_text('settings-sites', 'Example.com, another.org')
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-allow-any-site'))
		browser_settings_event('settings-apply')
		assert !browser_settings_visible()
		assert browsersettings.current().host == 'localhost'
		assert browsersettings.current().port == '9050'
		assert browsersettings.current().sites == 'example.com, another.org'
		assert browsersettings.current().allow_any_site
		show_browser_settings()
		ui2.set_text('settings-sites', 'discarded.example')
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-cancel'))
		show_browser_settings()
		assert ui2.text('settings-sites') == 'example.com, another.org'
		assert ui2.text('settings-error') == ''
		assert C.native_test_address_shortcut(ui2.embedded_browser_control('settings-port'), app, address_bar_shortcut, 53, 0) != 0
		assert !browser_settings_visible()
	}
}
